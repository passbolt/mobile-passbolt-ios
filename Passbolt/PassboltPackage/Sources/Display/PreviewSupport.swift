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
/// Preview support for ControlledView
@MainActor public func createPreview<V>(
  _ view: V.Type,
  with context: V.Controller.Context,
  using dependencies: @escaping (inout PreviewFeaturesContainer) -> Void,
  perform: @MainActor @escaping (V.Controller) async -> Void = { _ in }
) -> some View where V: ControlledView {
  do {
    var container = PreviewFeaturesContainer()
    V.Controller.previewDependencies(&container)
    dependencies(&container)
    let controller: V.Controller = try .init(context: context, features: container)
    let view: V = .init(controller: controller)
    return PreviewView.created(view, perform)
  }
  catch {
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
