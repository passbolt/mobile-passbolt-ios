# SwiftUI snapshot tests

SwiftUI snapshot testing built on
[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).
Coverage is **opt-in**: a preview is snapshot-tested when, and only when, a
registry under `Registry/` names it.

There is no code generation, no build-tool plugin and no third-party binary in
this pipeline. Enrolling a preview is one line of ordinary Swift.

## Layout

```
PassboltPackage/
├── Sources/SnapshotTestsSupport/          # Shared library
│   ├── SnapshotPreview.swift              # Registry entry model (`SnapshotPreview.of`)
│   ├── SnapshotDirectory.swift            # `assertSnapshots` + `SnapshotMatrix`
│   ├── SnapshotTestCase.swift             # XCTestCase base + `assertMatrix`
│   ├── ViewImageConfig+Missing.swift      # iPhone 17-family device configs
│   └── Snapshots/                         # Reference images (Git submodule)
└── Tests/SnapshotTests/
    ├── PreviewSnapshotTests.swift         # One test class per module
    └── Registry/
        ├── UICommonsPreviews.swift        # Which UICommons previews are covered
        └── SharedUIComponentsPreviews.swift
```

## Declaring a preview

Use `PreviewProvider` for anything you intend to snapshot-test:

```swift
#if DEBUG

internal struct AvatarView_Previews: PreviewProvider {

  internal static var previews: some View {
    AvatarView { Image(named: .person).resizable() }
  }
}
#endif
```

When a control has more than one state — enabled/disabled, selected, a role, a
permission, present/absent accessory — put **every state in one preview**, as a
`VStack` of instances, rather than declaring a provider per state:

```swift
internal static var previews: some View {
  VStack {
    PrimaryButton(title: "Primary button", action: {})
    PrimaryButton(title: "Disabled", disabled: .constant(true), action: {})
    PrimaryButton(title: "Icon", iconName: .trash, action: {})
    PrimaryButton(title: "Loading", isLoading: true, action: {})
  }
  .padding()
}
```

One reference image then covers the whole control, and a change to any state
shows up as a diff in a single file instead of being spread across several. It
also means the states are visually adjacent, which is what makes a failure
readable. A bare `ViewBuilder` tuple is **not** a substitute for the stack: it
has no layout of its own, so as a snapshot root its children overlap.

**Not** the `#Preview` macro. `#Preview` expands to a type whose view cannot be
recovered at runtime through any public API, so a preview declared that way can
only be snapshot-tested by copying its source text into the test target — which
breaks on `private` references and on identically-named types in different
modules (`SharedUIComponents.HelpMenuView` and `PassboltExtension.HelpMenuView`
are both `internal struct HelpMenuView`). `PreviewProvider.previews` is ordinary
public API and has neither problem, because the preview body never leaves its
own file.

`#Preview` remains perfectly fine for previews nobody wants pinned.

## Enrolling a preview

Add one line to the registry for its module:

```swift
// Registry/UICommonsPreviews.swift
private static let fitted: Array<any PreviewProvider.Type> = [
  AvatarView_Previews.self,
  // …
]
```

A registry groups its previews by layout — one array per layout, mapped to
`SnapshotPreview.of(_:module:layout:)` in `all` — so enrolling a component is a
single line in `fitted`, and a screen-level preview a single line in `device`.
See "Matrix and layout" below for which is which.

`SnapshotPreview.of` derives the reference image name from the type name minus
its `_Previews` suffix, so `AvatarView_Previews` records as `AvatarView`. Pass
`named:` to override when that would collide or confuse.

Because the entry names the *type*, renaming or deleting a preview is a compile
error — the test cannot silently disappear. The reverse is not true: **adding a
preview does not add coverage until someone adds a line here.** That is the
intended trade-off, and it is why the registries carry comments recording what
was deliberately left out.

To cover a new module: add `Registry/<Module>Previews.swift`, add the module to
the `SnapshotTests` dependencies in `Package.swift`, and add a test class to
`PreviewSnapshotTests.swift`.

## Matrix and layout

Every enrolled preview is rendered once per colour scheme
(`SnapshotMatrix.colorSchemes`). Whether it is *also* rendered once per device
depends on its layout:

```swift
.of(AvatarView_Previews.self, module: module)                        // .fitted (default)
.of(WarningView_Previews.self, module: module, layout: .fittedWidth) // spans its width
.of(MFAView_Previews.self, module: module, layout: .device)          // screen-level
```

- **`.fitted`** renders at the view's ideal size — no width and no height
  proposed. Correct only for views that have a size of their own: an icon, an
  indicator, a circular avatar. Records 2 images (light + dark).
- **`.fittedWidth`** renders at `SnapshotMatrix.fittedContentWidth` (320pt) with
  the height fitted to content. Records 2 images.
- **`.device`** renders onto the full device canvas, once per entry in
  `SnapshotMatrix.devices`. Use it when safe-area insets and available height are
  part of what you are pinning. Records 4 images.

**`.fittedWidth` is the right default for a component, and `.fitted` the special
case** — which is the opposite of what the enum ordering suggests. `.sizeThatFits`
proposes *nothing*, and a great many views cannot answer that:

- A view whose width comes from its parent reports **zero width** — a
  `GeometryReader`, a `.frame(maxWidth: .infinity)`, a `TextField`. A zero-size
  image is an error, not a comparison, so these fail loudly.
  `LinearProgressBar` and `EntropyView` are both a `GeometryReader` under a
  `.frame(maxWidth: .infinity)`: no width whatsoever of their own.
- Worse are the ones that fail *quietly*: a view with a small minimum rather
  than a hard zero still renders, but squashed to that minimum. A form field
  pinned that way records a shape the field never has in the app, and the long
  strings a preview uses to exercise wrapping and truncation never wrap.

Guessing wrong in the `.fittedWidth` direction costs a slightly wider image.
Guessing wrong the other way costs a broken or misleading baseline. When unsure,
give it a width.

Two cases need `.device` even though the thing under test is a single component:

- **The preview's root is a `List` or a `ScrollView`.** Neither has an ideal
  height, so under a fitted layout they collapse instead of laying content out.
  Either register `.device` or drop the scrolling container from the preview.
- **The view's layout is built out of `Spacer()`s.** A spacer's ideal length is
  zero, so fitting the canvas to the content removes the distribution the view
  exists to express. `OperationResultView` is the example: it centres content
  between two spacers and pins a button to the bottom edge.

Screen-level previews also want **one variant per canvas**, not a `VStack` of
several — the multi-state convention above is for controls. Three screens sharing
a canvas squash each other, which is the same failure in a different costume; give
each variant its own provider instead (see `OperationResultView_Previews` and
`OperationResultViewSuccess_Previews`).

This is not only about repository size. **A component rendered onto a full
device canvas is mostly empty background, and that dilutes the comparison.** Two
24pt icons occupy about 0.3% of an iPhone-sized image, so a pixel budget large
enough to absorb harmless rendering noise is also large enough to hide the icons
being deleted outright — which is exactly what happened here before
`precision` was tightened to `1.0`. Fitting the canvas to the component removes
the problem at its source.

If a snapshot starts flaking, tighten what is being rendered — or move it to
`.fitted` — rather than reintroducing a pixel budget. `perceptualPrecision`
exists to absorb per-pixel antialiasing and colour-space jitter and is the right
knob for that; `precision` is a *fraction of pixels allowed to differ*, and any
value below 1.0 scales with canvas area rather than with the thing under test.

Reference images live in a Git submodule, laid out
`<scheme>/<size>/<module>/preview.<name>.png`, where `<size>` is `fitted`,
`fitted-320` or `<width>x<height>` depending on the layout. The fitted width is
part of the directory name on purpose: changing `fittedContentWidth` then lands
in a new directory and records, rather than silently comparing fresh renders
against baselines recorded at the old width — swift-snapshot-testing
composes the file name from a prefix and the identifier passed as `named:`, and
`SnapshotTestCase` pins that prefix to a constant so image names depend only on
the preview, not on the test method that happens to render it. The module level
matters:
`PassboltApp` and `PassboltExtension` both declare `AuthorizationView` and
`AccountSelectionView`, which would otherwise overwrite each other.

## Reference images are a submodule

`Sources/SnapshotTestsSupport/Snapshots` points at
[passbolt-ios-screenshot-testing](https://gitlab.com/passbolt/mobile/passbolt-ios-screenshot-testing).
Binary baselines are rewritten on every intentional UI change, so keeping them
in a dedicated repository stops this one from accumulating dead PNG blobs.

It is mounted at that exact path — rather than somewhere tidier like the repo
root — because SwiftPM resource paths cannot escape their target directory. The
`.copy("Snapshots")` declaration, and with it the `Bundle.module` fallback that
makes snapshot tests work inside Xcode Cloud's simulator sandbox, only functions
if the images sit inside `Sources/SnapshotTestsSupport/`.

**After cloning:**

```bash
make snapshots_init      # git submodule update --init --recursive
```

Skipping this leaves an empty directory. `make snapshot_test` and
`make record_snapshots` both fail fast in that case rather than silently
recording a fresh set of baselines.

**When baselines change**, the submodule commit comes first:

```bash
make record_snapshots
git -C Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots add --all
git -C Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots commit -S -m "…"
git -C Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots push
git add Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots
```

The last `git add` records the new submodule SHA here. A merge request that
bumps the SHA without the corresponding push having landed will fail CI for
everyone else, so push the submodule first.

### Signed commits

The screenshot repository **requires GPG-signed commits**, and there is a trap
worth knowing about: a submodule keeps its own config at
`.git/modules/snapshots/config` and inherits only your **global** git config —
never the superproject's local one. Passbolt sets `commit.gpgsign` in
`passbolt-ios/.git/config`, which is invisible from inside the submodule, so
baseline commits silently come out unsigned and the remote rejects the push.

`make snapshots_init` copies the relevant settings across for you, and
`make record_snapshots` refuses to run until signing is configured — commits are
about to be produced at that point, so failing early beats failing at push. To
apply it by hand at any time:

```bash
./Tools/snapshots/configure-signing.sh          # warns if signing is unavailable
./Tools/snapshots/configure-signing.sh --require # exits non-zero instead
```

If you have no signing key set up yet, configuring it globally avoids the whole
class of problem:

```bash
git config --global user.signingkey <your-key-id>
git config --global commit.gpgsign true
```

To check that a commit actually carries a signature — `N` means unsigned, `G`
means a good signature:

```bash
git -C Passbolt/PassboltPackage/Sources/SnapshotTestsSupport/Snapshots \
  log --format='%h %G? %s' -3
```

`Tools/snapshots/bootstrap-submodule.sh` performs the one-time setup — seeding
the screenshot repository, untracking the images here, registering the
submodule. It needs push access to both repositories and runs once.

## Running

**From Xcode** — select the shared `PassboltSnapshots` scheme, then `⌘ + U`. The
regular `Passbolt` scheme does **not** run snapshot tests; it uses
`TestPlan.xctestplan`, which lists only the unit-test targets.

To record baselines from Xcode: `Edit Scheme… → Test → Arguments → Environment
Variables`, set `SNAPSHOT_TESTING_RECORD=true`, and unset it afterwards.
`SnapshotTestCase` reads it in `invokeTest()` and scopes each test in
`withSnapshotTesting(record: .all)`; without it the record mode is `.missing`
(records on first run, compares thereafter).

**From the command line**, at the repository root:

```bash
make snapshots_init      # populate the reference-image submodule (one-time)
make snapshot_test       # compare against baselines
make record_snapshots    # write/refresh baselines
```

Both test commands target the `PassboltSnapshots` scheme and
`SnapshotTestPlan.xctestplan`, so they stay isolated from `make test`.

## Portability between machines

A reference image is only useful if the same view renders to the same *pixels*
on every machine. Two things decide that, and neither can be left to the host.

**Display scale.** `UIGraphicsImageRendererFormat(for:)` falls back to the
render environment when a trait collection leaves `displayScale` unspecified, so
a canvas that does not pin it rasterises at whatever scale the simulator running
the tests happens to use. Nothing warns you: the images look right, and they
compare fine against themselves on the machine that recorded them. On a host
with a different scale every comparison then fails at once, and it fails with
`Newly-taken snapshot@… does not match reference@…` — a *dimension* mismatch,
which tells you nothing about what changed.

swift-snapshot-testing does **not** do this for you:
`UITraitCollection.iPhone8(_:)` leaves `displayScale` unspecified, as do the
iPhone 17-family configs transcribed from an upstream pull request into
`ViewImageConfig+Missing.swift`.

**Setting it on a `ViewImageConfig` is not enough, and this is the trap.**
`snapshotView` builds the renderer as `renderer(bounds:for: traits)` — the
traits it was *called* with. The config's own traits go to `prepareView` and no
further, so they never reach `UIGraphicsImageRendererFormat`. A device pinned
only on its config still rasterises at the host's scale, and it does so
silently: it looks correct wherever it was recorded.

So the scale always travels in the traits passed to `.image(traits:)`, which is
what `assertSnapshots` does:

- A **device** declares its real scale in `SnapshotMatrix.devices` — 2x for
  iPhone 8, 3x for iPhone 17 Pro Max — via
  `pinningDisplayScaleIfUnspecified(_:)`, which leaves alone any config that
  already states one. `assertSnapshots` reads it back off the config and renders
  with it. `DeviceMatrixTests` fails the build if a device in the matrix ends up
  without a scale.
- A **fitted** canvas has no device, so it gets
  `SnapshotMatrix.fittedDisplayScale` (2x). The value is arbitrary — being fixed
  is the whole point. Changing it invalidates every fitted baseline.

**Simulator runtime.** `.sizeThatFits` resolves a height from system font
metrics, and those move between iOS releases. A fitted image recorded against
one runtime can be a point or two taller against another, which surfaces as the
same dimension mismatch. The device in `SNAPSHOT_PLATFORM` no longer matters
after the above, but the runtime does: pin it with
`make snapshot_test SNAPSHOT_OS=26.0` when your local Xcode and the Xcode Cloud
workflow's Xcode differ.

**Rendering jitter.** Once the dimensions agree, what is left is that the same
view does not rasterise byte-identically on two different machines. Between a
developer's Mac and Xcode Cloud's virtualised host the measured difference is
1–2 of 255 on the antialiased edges of glyphs and icons — between 7 and 260
pixels of an image, alpha identical, invisible at any zoom. This is not
something to record away: it will reappear on the next machine.

`perceptualPrecision` is the knob for it, and **0.98 is too tight**: it allows
ΔE 2.0, the library scores that jitter at ΔE 2.2–3.75, and because `precision`
is `1.0` a single pixel over the line fails the whole image. At 0.98 it failed
22 of 144, 19 of them in dark mode. It is set to **0.95** — ΔE 5, comfortably
over the worst observed, and still nowhere near loose enough to hide a control
changing colour or disappearing. Raise it back the moment the jitter has another
explanation; loosening `precision` instead is still the wrong move, for the
reason under "Matrix and layout".

## CI notes

`-skipMacroValidation` is passed to `xcodebuild` because swift-snapshot-testing
brings a swift-syntax macro into the graph and CI has no human to answer Xcode's
interactive trust prompt. `-skipPackagePluginValidation` is deliberately **not**
passed — this project uses no SwiftPM build-tool plugins, and it should stay
that way. A plugin executes arbitrary code on every build.

Xcode Cloud shallow-clones the primary repository only, so `ci_post_clone.sh`
explicitly runs `git submodule update --init` for the reference images and fails
the build if the directory comes back empty. The screenshot repository must be
listed as an additional repository in the Xcode Cloud workflow's source settings
for that checkout to be authorised.

## Known limitations

- **Dark-mode colour fidelity for `passbolt*` colours.**
  `UICommons/Colors.swift` resolves named colours eagerly via
  `UIColor(named:in:compatibleWith: .current)`, collapsing each to a single
  static `UIColor` at access time. SwiftUI cannot redraw these dynamically
  because the dark-mode resolver is already gone. The `performAsCurrent`-based
  wrapper in `assertSnapshots` mitigates this for lookups that happen on the
  main thread during the render, but any colour captured earlier (init paths,
  static `let`s, caches) keeps its original variant. The permanent fix is to
  change `Colors.swift` to return
  `UIColor { traits in UIColor(named: …, compatibleWith: traits) }` dynamic
  providers — about 30–40 single-line changes, backwards-compatible at call
  sites, and it also fixes a latent production bug where mid-session
  Settings → Dark Mode toggles can leave stale colours on screen.

- **Anything driven by the clock cannot be pinned.** An indeterminate
  `SwiftUI.ProgressView`, a `Timer.publish` preview, a `time(nil)` call, a
  randomised `Task.sleep`, or an async load racing the render all produce a
  different image depending on when the renderer captured the frame. Because
  `precision` is `1.0` there is no threshold that would absorb this while still
  catching a deleted control, so these previews are left out of the registry and
  the reason is recorded there. `Loader_Previews`,
  `CommonListResourceOTPView_Previews` and `CountdownCircleViewRunning_Previews`
  are the current cases. The fix, when one is wanted, is a preview built from a
  fixed value rather than a live source — `CountdownCircleView_Previews` and
  `TOTPValueView_Previews` are the pattern.

- **`.sheet(isPresented:)` content is invisible to snapshots.**
  SwiftUI presents sheets in a separate window scene, not as a subview of the
  hosting controller, so a preview shaped as
  `BaseView().sheet(isPresented: .constant(true)) { SheetContent() }` captures
  only `BaseView`. `HelpMenuView_Previews` and `LogsViewerView_Previews` are
  affected and are deliberately left out of the registry. To snapshot a sheet's
  body, add a preview that renders its content directly.

- **DI-bound previews.** Previews built through `createPreview()` in
  `Display/PreviewSupport.swift` work as-is — the helper resolves feature
  dependencies through `PreviewFeaturesContainer`, and because the registry
  references the provider type rather than copying its body, that resolution
  happens exactly where it does in the Xcode canvas.

- **Scope.** `PassboltApp` and `PassboltExtension` are not yet enrolled. Their
  previews are DI-bound and worth validating as their own step; adding them is
  a new registry file plus a dependency, not a structural change.
