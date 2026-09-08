//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

#if DEBUG

/// Builds the `V.Controller` a preview needs — patched with `previewDependencies` plus any extra
/// `dependencies` — shared by `createPreview` and `createSnapshotPreview` so the container/DI
/// setup exists in exactly one place.
@MainActor private func makePreviewController<V>(
  _ view: V.Type,
  with context: V.Controller.Context,
  using dependencies: (inout PreviewFeaturesContainer) -> Void
) -> Result<V.Controller, Error> where V: ControlledView {
  do {
    var container = PreviewFeaturesContainer()
    V.Controller.previewDependencies(&container)
    dependencies(&container)
    return .success(try .init(context: context, features: container))
  }
  catch {
    return .failure(error)
  }
}

/// Preview support for ControlledView
@MainActor public func createPreview<V>(
  _ view: V.Type,
  with context: V.Controller.Context,
  using dependencies: @escaping (inout PreviewFeaturesContainer) -> Void,
  perform: @MainActor @escaping (V.Controller) async -> Void = { _ in }
) -> some View where V: ControlledView {
  switch makePreviewController(view, with: context, using: dependencies) {
  case .success(let controller):
    let view: V = .init(controller: controller)
    return PreviewView.created(view, perform)
  case .failure(let error):
    return PreviewView<V>.error(error)
  }
}

@MainActor
public func createPreview<V>(
  _ view: V.Type,
  using dependencies: @escaping (inout PreviewFeaturesContainer) -> Void = { _ in },
  perform: @MainActor @escaping (V.Controller) async -> Void = { _ in }
) -> some View where V: ControlledView, V.Controller.Context == Void {
  createPreview(view, with: (), using: dependencies, perform: perform)
}

@MainActor
public func createPreview<V>(
  _ view: V.Type,
  with context: V.Controller.Context,
  perform: @MainActor @escaping (V.Controller) async -> Void = { _ in }
) -> some View where V: ControlledView {
  createPreview(view, with: context, using: { _ in }, perform: perform)
}

private enum PreviewView<V>: View where V: ControlledView {
  case created(V, @MainActor (V.Controller) async -> Void)
  case error(Error)

  fileprivate var body: some View {
    switch self {
    case .created(let view, let perform):
      view.task { await perform(view.controller) }
    case .error(let error):
      Text("Error!: \(error.localizedDescription)")
    }
  }
}

public typealias PreviewReadyCallback<V: ControlledView> = @MainActor (V.Controller) async -> Void

/// Like `createPreview`, but for a screen whose content depends on async-loaded state (a DI-bound
/// controller using `ViewStateSource`'s reactive `updateFrom:` pipeline). `ready` is awaited to
/// completion BEFORE the view is returned, rather than via a `.task` on the rendered view — a
/// snapshot test captures a single frame with no guarantee any `.task` has finished by then, so
/// the load has to happen before the view exists, not after.
///
/// `ready` defaults to awaiting the controller's own `viewState.current`, which is enough for a
/// screen whose visible content comes straight from its top-level `ViewState` — most screens.
/// Pass one explicitly only when there's more to settle, e.g. a screen composed of nested
/// controllers whose own reactive state isn't reachable through the top-level `viewState` at all.
@MainActor public func createSnapshotPreview<V>(
  _ view: V.Type,
  with context: V.Controller.Context,
  using dependencies: @escaping (inout PreviewFeaturesContainer) -> Void = { _ in },
  ready: PreviewReadyCallback<V>? = .none
) async -> some View where V: ControlledView {
  switch makePreviewController(view, with: context, using: dependencies) {
  case .success(let controller):
    let ready: PreviewReadyCallback<V> = ready ?? { controller in _ = await controller.viewState.current }
    await ready(controller)
    return AnyView(V(controller: controller))
  case .failure(let error):
    return AnyView(Text("Error!: \(error.localizedDescription)"))
  }
}

@MainActor public func createSnapshotPreview<V>(
  _ view: V.Type,
  using dependencies: @escaping (inout PreviewFeaturesContainer) -> Void = { _ in },
  ready: PreviewReadyCallback<V>? = .none
) async -> some View where V: ControlledView, V.Controller.Context == Void {
  await createSnapshotPreview(view, with: (), using: dependencies, ready: ready)
}

private struct NavigationStackWrapper: ViewModifier {

  fileprivate func body(content: Content) -> some View {
    NavigationStack {
      content
    }
  }
}

extension View {

  public func wrapInNavigationStack() -> some View {
    modifier(NavigationStackWrapper())
  }
}
#endif
