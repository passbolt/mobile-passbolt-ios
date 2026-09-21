#!/bin/bash
#
# adopt-xcframework.sh
#
# Replaces the vendored Gopenpgp.xcframework with the one built by
# build-xcframework.sh, then runs the crypto tests against it.
#
# Kept separate from the build so that producing a framework never touches the
# working tree: a build can be inspected and thrown away, and only this script
# commits to using it.
#
# Usage:
#   Tools/gopenpgp/adopt-xcframework.sh
#
# Environment overrides:
#   SOURCE_FRAMEWORK  framework to adopt (default: Tools/gopenpgp/dist/...)
#   DESTINATION       simulator to run the tests on

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly FRAMEWORK_NAME="Gopenpgp"
readonly SOURCE_FRAMEWORK="${SOURCE_FRAMEWORK:-${REPO_ROOT}/Tools/gopenpgp/dist/${FRAMEWORK_NAME}.xcframework}"
readonly VENDOR_DIR="${REPO_ROOT}/Passbolt/PassboltPackage/Vendor/Frameworks"
readonly VENDORED_FRAMEWORK="${VENDOR_DIR}/${FRAMEWORK_NAME}.xcframework"
# Matches the Makefile's TEST_PLATFORM.
readonly DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
readonly REVERT_COMMAND="git checkout -- Passbolt/PassboltPackage/Vendor/Frameworks/${FRAMEWORK_NAME}.xcframework"

log() {
	printf '\n==> %s\n' "$1"
}

if [ ! -d "${SOURCE_FRAMEWORK}" ]; then
	echo "error: ${SOURCE_FRAMEWORK} does not exist." >&2
	echo "       Run Tools/gopenpgp/build-xcframework.sh first." >&2
	exit 1
fi

# A gomobile bind that fails halfway can leave a directory behind that looks like
# an xcframework but has no slices in it. Replacing the vendored framework with
# one of those produces a link error with no obvious cause.
if [ ! -f "${SOURCE_FRAMEWORK}/Info.plist" ]; then
	echo "error: ${SOURCE_FRAMEWORK} has no Info.plist — it is not a complete xcframework." >&2
	exit 1
fi

if [ ! -d "${VENDOR_DIR}" ]; then
	echo "error: ${VENDOR_DIR} does not exist." >&2
	exit 1
fi

log "Replacing the vendored framework"
echo "  from ${SOURCE_FRAMEWORK}"
echo "  to   ${VENDORED_FRAMEWORK}"
# The framework being replaced is tracked by git, so this is reversible with the
# revert command printed below.
rm -rf "${VENDORED_FRAMEWORK}"
cp -R "${SOURCE_FRAMEWORK}" "${VENDORED_FRAMEWORK}"

log "Running CryptoTests against the adopted framework"
# The tests are not run through `make test`: the whole suite takes far longer and
# says nothing more about whether this particular binary encrypts and decrypts.
if xcodebuild \
	-project "${REPO_ROOT}/Passbolt/Passbolt.xcodeproj" \
	-scheme Passbolt \
	-destination "${DESTINATION}" \
	-only-testing:CryptoTests \
	test; then
	cat <<EOF

CryptoTests passed against the adopted framework.

Review and commit:
  git add Passbolt/PassboltPackage/Vendor/Frameworks/${FRAMEWORK_NAME}.xcframework

To go back to the previously vendored framework:
  ${REVERT_COMMAND}
EOF
else
	cat <<EOF

CryptoTests FAILED against the adopted framework.

The framework is left in place so the failure can be investigated. To go back to
the previously vendored one:
  ${REVERT_COMMAND}
EOF
	exit 1
fi
