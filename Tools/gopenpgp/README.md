# Gopenpgp.xcframework

`Passbolt/PassboltPackage/Vendor/Frameworks/Gopenpgp.xcframework` is a binary
dependency: the [GopenPGP](https://github.com/ProtonMail/gopenpgp) library bound
for iOS with `gomobile`. These two scripts build it and put it in place. Both
require macOS with Xcode command line tools.

## Building

```bash
Tools/gopenpgp/build-xcframework.sh
```

Downloads Go and gomobile at pinned versions, checks out the pinned GopenPGP
tag, runs GopenPGP's own Go test suite, and binds the framework for device and
simulator. The result is written to `Tools/gopenpgp/dist/`; nothing in the
working tree is touched.

The test suite takes a few seconds and a failure stops the build, so a broken
library is caught before the twenty-minute bind rather than inside the app.
`SKIP_TESTS=1` bypasses it.

The build also compares its bound package list and build tags against the
`build.sh` of the tag it is building — the only two values copied from upstream
by hand. A difference is reported and the build continues; on a version bump an
added package is usually deliberate, and the note is there so it gets noticed
rather than discovered later.

The GopenPGP, Go and gomobile versions are the first three values at the top of
the script. Changing the GopenPGP version there is all an upgrade takes.

## Adopting

```bash
Tools/gopenpgp/adopt-xcframework.sh
```

Replaces the vendored framework with the one in `dist/` and runs `CryptoTests`
against it. The framework is tracked by git, so the swap is undone with:

```bash
git checkout -- Passbolt/PassboltPackage/Vendor/Frameworks/Gopenpgp.xcframework
```
