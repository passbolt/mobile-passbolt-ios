#!/bin/bash
#
# build-xcframework.sh
#
# Builds Gopenpgp.xcframework from GopenPGP sources using gomobile.
# Runs identically on a developer Mac and on Xcode Cloud; the only requirement
# is macOS with Xcode command line tools. Go and gomobile are downloaded into
# the work directory at pinned versions, so nothing is taken from the host.
#
# The result is written to Tools/gopenpgp/dist/Gopenpgp.xcframework and is NOT
# copied into Vendor/ — replacing the vendored framework stays a manual,
# reviewed step.
#
# Usage:
#   Tools/gopenpgp/build-xcframework.sh
#
# Environment overrides:
#   WORK_DIR   scratch directory for the Go toolchain and the GopenPGP checkout
#   OUT_DIR    directory the finished xcframework is written to
#   SKIP_TESTS set to 1 to skip GopenPGP's own Go test suite

set -euo pipefail

# MARK: - Pinned versions
#
# Every one of these is part of the build's identity. Changing any of them
# changes the produced binary, so they are pinned here rather than taken from
# whatever happens to be installed on the machine.

# GopenPGP release tag to build.
readonly GOPENPGP_VERSION="v3.4.1"
# Go toolchain. Matches the toolchain the currently vendored framework was
# built with (read out of the shipped binary).
readonly GO_VERSION="1.23.2"
# gomobile/gobind. Same source of truth as above.
readonly GOMOBILE_VERSION="v0.0.0-20250408133729-978277e7eaf7"

# Build tags and package list are taken verbatim from GopenPGP's own build.sh
# for this tag. The `mobile,ios` tags select the mobile-friendly API surface;
# without them the generated headers differ. `crypto` must stay first — gomobile
# names the framework after the first package.
#
# Checked back against upstream's build.sh on every build, see below.
readonly BUILD_TAGS="mobile,ios"
readonly PACKAGES=(
	"github.com/ProtonMail/gopenpgp/v3/crypto"
	"github.com/ProtonMail/gopenpgp/v3/armor"
	"github.com/ProtonMail/gopenpgp/v3/constants"
	"github.com/ProtonMail/gopenpgp/v3/mime"
	"github.com/ProtonMail/gopenpgp/v3/mobile"
	"github.com/ProtonMail/gopenpgp/v3/profile"
)

# Upstream builds ios,iossimulator,macos. Passbolt ships iOS only, and the macOS
# slice would add ~15 MB to the repository for nothing.
readonly TARGETS="ios,iossimulator"

# Upstream writes `gopenpgp.xcframework` (lowercase). Package.swift references
# `Gopenpgp.xcframework`, and a repository that has held both spellings at once
# cannot be checked out on a case-insensitive filesystem. The capitalised name
# is the one this project uses.
readonly FRAMEWORK_NAME="Gopenpgp"

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Deliberately outside the repository and outside $HOME. -trimpath rewrites the
# source paths inside the binary but not the module root itself, which stays
# embedded as an absolute path — so a work directory under the home folder puts
# the developer's user name into the framework. TMPDIR on macOS is a private
# per-user path that contains no user name, which makes a local build produce the
# same clean binary as an Xcode Cloud one. The cost is that macOS eventually
# purges it and the Go toolchain is downloaded again.
readonly WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/passbolt-gopenpgp}"
readonly OUT_DIR="${OUT_DIR:-${REPO_ROOT}/Tools/gopenpgp/dist}"
readonly VENDORED_FRAMEWORK="${REPO_ROOT}/Passbolt/PassboltPackage/Vendor/Frameworks/${FRAMEWORK_NAME}.xcframework"

log() {
	printf '\n==> %s\n' "$1"
}

# MARK: - Preflight

if [ "$(uname -s)" != "Darwin" ]; then
	echo "error: gomobile can only produce an xcframework on macOS." >&2
	exit 1
fi

if ! xcode-select --print-path > /dev/null 2>&1; then
	echo "error: no Xcode toolchain selected (xcode-select --print-path failed)." >&2
	exit 1
fi

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

# MARK: - Go toolchain
#
# Downloaded rather than assumed: Xcode Cloud images ship no Go at all, and a
# developer Mac usually has whatever version asdf/brew last installed.

readonly GO_ROOT="${WORK_DIR}/go-${GO_VERSION}"

if [ ! -x "${GO_ROOT}/bin/go" ]; then
	case "$(uname -m)" in
		arm64) GO_ARCH="arm64" ;;
		x86_64) GO_ARCH="amd64" ;;
		*)
			echo "error: unsupported host architecture $(uname -m)." >&2
			exit 1
			;;
	esac
	readonly GO_TARBALL="go${GO_VERSION}.darwin-${GO_ARCH}.tar.gz"
	log "Downloading ${GO_TARBALL}"
	curl --fail --location --show-error --silent \
		--output "${WORK_DIR}/${GO_TARBALL}" \
		"https://go.dev/dl/${GO_TARBALL}"
	rm -rf "${GO_ROOT}"
	mkdir -p "${GO_ROOT}"
	tar --extract --gzip --strip-components=1 \
		--file "${WORK_DIR}/${GO_TARBALL}" \
		--directory "${GO_ROOT}"
	rm -f "${WORK_DIR}/${GO_TARBALL}"
fi

export GOROOT="${GO_ROOT}"
export GOPATH="${WORK_DIR}/gopath"
export PATH="${GO_ROOT}/bin:${GOPATH}/bin:${PATH}"

export CGO_ENABLED=1

log "Go toolchain: $(go version)"

# MARK: - GopenPGP sources
#
# A tagged git checkout, so the build can state exactly what it built. The
# currently vendored framework was made from an unpacked tarball in a Downloads
# folder, which leaves no way to prove which revision it came from.

readonly SOURCE_DIR="${WORK_DIR}/gopenpgp"

if [ ! -d "${SOURCE_DIR}/.git" ]; then
	log "Cloning GopenPGP ${GOPENPGP_VERSION}"
	rm -rf "${SOURCE_DIR}"
	git clone --depth 1 --branch "${GOPENPGP_VERSION}" \
		https://github.com/ProtonMail/gopenpgp.git "${SOURCE_DIR}"
else
	log "Reusing GopenPGP checkout in ${SOURCE_DIR}"
	# The refspec has to name a destination. `git fetch origin refs/tags/X` alone
	# only writes FETCH_HEAD, so on a shallow clone made for an earlier version the
	# new tag never becomes a local ref and the checkout below fails with
	# "pathspec did not match". --force lets a moved tag be picked up too.
	git -C "${SOURCE_DIR}" fetch --depth 1 --force origin \
		"refs/tags/${GOPENPGP_VERSION}:refs/tags/${GOPENPGP_VERSION}"
	git -C "${SOURCE_DIR}" checkout --force "${GOPENPGP_VERSION}"
fi

readonly SOURCE_REVISION="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
log "GopenPGP ${GOPENPGP_VERSION} at ${SOURCE_REVISION}"

# MARK: - Upstream drift check
#
# BUILD_TAGS and PACKAGES are the only hand-copied values here; the rest of the
# build derives from the tag's go.mod. Reported, never fatal — on a version bump
# an added package is usually intended.
#
# Reads the build.sh from the checkout, so no network and always the right tag.

readonly UPSTREAM_BUILD_SCRIPT="${SOURCE_DIR}/build.sh"
# Upstream builds the Apple tags in two steps in build(). Pinned literally
# rather than evaluated out of someone else's shell.
readonly EXPECTED_UPSTREAM_TAGS='TAGS="mobile" TAGS="$TAGS,ios"'

# $2 is optional detail, printed above the footer rather than below it.
drift_warning() {
	echo "" >&2
	echo "note: this script has drifted from upstream's build.sh." >&2
	echo "      $1" >&2
	if [ "$#" -gt 1 ]; then
		printf '%s\n' "$2" >&2
	fi
	echo "      Review Tools/gopenpgp/build-xcframework.sh before shipping the result." >&2
}

log "Checking BUILD_TAGS and PACKAGES against upstream's build.sh"

if [ ! -f "${UPSTREAM_BUILD_SCRIPT}" ]; then
	drift_warning "Upstream no longer ships build.sh, so the check could not run."
else
	# Order matters as much as membership: the first package names the framework.
	upstream_packages="$(sed -n 's/^import[[:space:]]\{1,\}\(github\.com[^[:space:]]*\).*$/\1/p' "${UPSTREAM_BUILD_SCRIPT}")"
	our_packages="$(printf '%s\n' "${PACKAGES[@]}")"

	if [ -z "${upstream_packages}" ]; then
		drift_warning "No 'import github.com/...' lines found in upstream's build.sh; it has been restructured."
	elif [ "${upstream_packages}" != "${our_packages}" ]; then
		drift_warning \
			"The bound package list differs. Upstream on the left, this script on the right:" \
			"$(diff --side-by-side \
				<(printf '%s\n' "${upstream_packages}") \
				<(printf '%s\n' "${our_packages}") || true)"
	else
		echo "Package list matches upstream (${#PACKAGES[@]} packages)."
	fi

	upstream_tags="$(sed -n 's/^[[:space:]]*\(TAGS="[^"]*"\).*$/\1/p' "${UPSTREAM_BUILD_SCRIPT}" | paste -sd' ' -)"

	if [ "${upstream_tags}" != "${EXPECTED_UPSTREAM_TAGS}" ]; then
		drift_warning \
			"Upstream's tag assignments changed, so BUILD_TAGS=\"${BUILD_TAGS}\" may be stale." \
			"      expected: ${EXPECTED_UPSTREAM_TAGS}
      found:    ${upstream_tags:-<none>}"
	else
		echo "Build tags match upstream (${BUILD_TAGS})."
	fi
fi

cd "${SOURCE_DIR}"
go mod download

# MARK: - Upstream test suite
#
# Runs before gomobile: the `go get` below rewrites go.mod, so this is the last
# point where the dependency set is the one the tag was released with.
#
# The bind uses `mobile,ios`, the tests only `mobile`. `ios` is a GOOS name, not
# a plain tag, and passing it to a host build breaks the standard library.
# GopenPGP's own sources carry no build constraints, so it covers the same code.
#
# -cover matches what the Android build runs. It reports armor and profile at
# 0.0%: both are bound into the framework and have no upstream tests at all.

if [ "${SKIP_TESTS:-0}" = "1" ]; then
	log "Skipping the GopenPGP test suite (SKIP_TESTS=1)"
else
	log "Running the GopenPGP test suite"
	go test -cover -tags mobile ./...
fi

# MARK: - gomobile
#
# gomobile has to be installed from inside the module being bound, not globally.
# gobind resolves golang.org/x/mobile/bind through the target module's dependency
# graph, so unless x/mobile is a dependency of GopenPGP itself the bind fails with
# "no Go package in golang.org/x/mobile/bind".
#
# `go get` therefore writes to the checkout's go.mod, pulling in x/mobile and its
# own dependencies. That means the dependency set is no longer exactly the one the
# GopenPGP tag was released with — unavoidable, and what upstream's build.sh does
# too. The checkout is scratch, so the edit is discarded with it.

log "Installing gomobile ${GOMOBILE_VERSION} into the GopenPGP module"
go get "golang.org/x/mobile/cmd/gomobile@${GOMOBILE_VERSION}"
go get "golang.org/x/mobile/cmd/gobind@${GOMOBILE_VERSION}"

# Built from the module rather than `go install`ed, so the gomobile binary and the
# bind support packages come from one and the same revision.
readonly TOOLS_BIN="${WORK_DIR}/bin"
mkdir -p "${TOOLS_BIN}"
go build -o "${TOOLS_BIN}/gomobile" golang.org/x/mobile/cmd/gomobile
# gomobile invokes gobind as a subprocess and finds it on PATH.
go build -o "${TOOLS_BIN}/gobind" golang.org/x/mobile/cmd/gobind
export PATH="${TOOLS_BIN}:${PATH}"

gomobile init

# MARK: - Bind

readonly OUTPUT_FRAMEWORK="${OUT_DIR}/${FRAMEWORK_NAME}.xcframework"
rm -rf "${OUTPUT_FRAMEWORK}"

# -trimpath strips absolute source paths from the binary. Without it the
# framework embeds the build machine's home directory, and the vendored framework
# built by hand carries /Users/<developer>/Downloads/... into the App Store build.
#
# It has to be a gomobile flag, not GOFLAGS. gomobile assembles the environment
# for the `go build` subprocesses itself and sets GOFLAGS to its own platform tags
# (cmd/gomobile/env.go), and its `environ` helper gives those precedence over the
# inherited environment — so an exported GOFLAGS=-trimpath is silently discarded.
# gomobile's own -trimpath flag is forwarded to every go invocation it makes
# (cmd/gomobile/build.go).
log "Running gomobile bind for ${TARGETS}"
gomobile bind \
	-trimpath \
	-tags "${BUILD_TAGS}" \
	-target "${TARGETS}" \
	-ldflags="-s -w" \
	-o "${OUTPUT_FRAMEWORK}" \
	"${PACKAGES[@]}"

# MARK: - Metadata
#
# gomobile stamps the framework with a Unix timestamp as its version, which
# makes it impossible to tell from a built artifact which GopenPGP it contains.
# Replace it with the release tag. MinimumOSVersion is deliberately left at
# gomobile's value — the shipped framework has always carried it and changing it
# would alter linking behaviour, which is not this script's business.

readonly PLIST_BUDDY="/usr/libexec/PlistBuddy"
readonly SHORT_VERSION="${GOPENPGP_VERSION#v}"

while IFS= read -r plist; do
	"${PLIST_BUDDY}" -c "Set :CFBundleShortVersionString ${SHORT_VERSION}" "${plist}"
	"${PLIST_BUDDY}" -c "Set :CFBundleVersion ${SHORT_VERSION}" "${plist}"
done < <(find "${OUTPUT_FRAMEWORK}" -name Info.plist -path "*${FRAMEWORK_NAME}.framework*")

# MARK: - Report

log "Built ${OUTPUT_FRAMEWORK}"
du -sh "${OUTPUT_FRAMEWORK}"

# -trimpath is the whole reason the built binary does not carry the build
# machine's home directory, and a dropped -trimpath puts it back without any
# other visible symptom. Fatal rather than a warning: the framework ends up
# inside an App Store build, so a leak here ships.
log "Checking the binary for leaked host paths"
if find "${OUTPUT_FRAMEWORK}" -type f -name "${FRAMEWORK_NAME}" -exec strings {} + | grep -q "/Users/"; then
	echo "error: the built binary contains absolute host paths (/Users/...)." >&2
	echo "       -trimpath did not take effect; check the gomobile bind flags." >&2
	exit 1
fi
echo "No host paths in the binary."

# A header that differs from the vendored framework means the generated Objective-C
# surface changed, and Crypto/PGP.swift may no longer compile against it. Reported,
# not enforced — on a version bump a difference is the expected outcome.
if [ -d "${VENDORED_FRAMEWORK}" ]; then
	log "Comparing generated headers against the vendored framework"
	if diff --recursive --brief \
		"${VENDORED_FRAMEWORK}/ios-arm64/${FRAMEWORK_NAME}.framework/Headers" \
		"${OUTPUT_FRAMEWORK}/ios-arm64/${FRAMEWORK_NAME}.framework/Headers"; then
		echo "Headers are identical to the vendored framework."
	else
		echo "note: headers differ from the vendored framework (expected on a version bump)."
	fi
fi

cat <<EOF

Built GopenPGP ${GOPENPGP_VERSION} (${SOURCE_REVISION})
  Go        ${GO_VERSION}
  gomobile  ${GOMOBILE_VERSION}
  targets   ${TARGETS}
  output    ${OUTPUT_FRAMEWORK}

To adopt it — replace the vendored framework and run the crypto tests:
  Tools/gopenpgp/adopt-xcframework.sh
EOF
