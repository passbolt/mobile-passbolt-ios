#!/bin/sh

# ci_post_clone.sh
# Runs on Xcode Cloud after the repository is cloned, before dependencies
# are resolved and the build starts. The working directory when invoked is
# this script's directory ($CI_PRIMARY_REPOSITORY_PATH/ci_scripts).
#
# Useful environment variables provided by Xcode Cloud:
#   CI                          - "TRUE" when running on Xcode Cloud
#   CI_WORKFLOW                 - Name of the active workflow
#   CI_PRIMARY_REPOSITORY_PATH  - Absolute path to the cloned repo
#   CI_DERIVED_DATA_PATH        - DerivedData path for the build
#   CI_PRODUCT_PLATFORM         - e.g. iOS
#
# A non-zero exit fails the build.

set -eu

# NOTE: this project deliberately uses no SwiftPM build-tool plugins, so there is
# no plugin-trust fingerprint to pre-seed here. If you are about to add one, weigh
# the supply-chain cost first — a plugin executes arbitrary code on every build.

# Snapshot reference images live in the passbolt-ios-screenshot-testing repo,
# mounted as a submodule. Xcode Cloud performs a shallow clone of the primary
# repository only, so the submodule has to be fetched explicitly. Without it,
# SnapshotTestsSupport's `.copy("Snapshots")` resource is an empty directory and
# every snapshot test silently records a new baseline instead of comparing.
#
# Requires the screenshot repository to be reachable with the same credentials
# as the primary one — on Xcode Cloud that means adding it as an additional
# repository in the workflow's source settings.
SNAPSHOTS_PATH="Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots"
cd "${CI_PRIMARY_REPOSITORY_PATH:-../..}"
git submodule sync --recursive
git submodule update --init --recursive -- "${SNAPSHOTS_PATH}"

if [ -z "$(ls -A "${SNAPSHOTS_PATH}" 2>/dev/null)" ]; then
	echo "error: snapshot reference-image submodule is empty after checkout." >&2
	echo "       Snapshot tests would record new baselines instead of comparing." >&2
	exit 1
fi

