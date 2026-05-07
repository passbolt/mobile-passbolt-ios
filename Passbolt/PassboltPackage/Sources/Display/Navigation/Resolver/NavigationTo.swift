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

import Features

public struct NavigationTo<Destination>: @unchecked Sendable
where Destination: NavigationDestination {

  @usableFromInline internal var performAnimated:
    @Sendable (
      _ animated: Bool,
      _ context: Destination.TransitionContext,
      _ file: StaticString,
      _ line: UInt
    ) async throws -> Void

  @usableFromInline internal var revertAnimated:
    @Sendable (
      _ animated: Bool,
      _ file: StaticString,
      _ line: UInt
    ) async throws -> Void

  @usableFromInline internal var canPerformCheck:
    (
      _ file: StaticString,
      _ line: UInt
    ) -> Bool

}

extension NavigationTo: LoadableFeature {

  public nonisolated static var placeholder: Self {
    .init(
      performAnimated: unimplemented4(),
      revertAnimated: unimplemented3(),
      canPerformCheck: unimplemented2()
    )
  }
  #if DEBUG
  public var mockPerform: @Sendable (Bool, Destination.TransitionContext) async throws -> Void {
    get { unimplemented2("Mock can't be used, it is intended only as a helper to patch in test.") }
    set {
      self.performAnimated = { animated, context, _, _ in
        try await newValue(animated, context)
      }
    }
  }

  public var mockRevert: @Sendable (Bool) async throws -> Void {
    get { unimplemented1("Mock can't be used, it is intended only as a helper to patch in test.") }
    set {
      self.revertAnimated = { animated, _, _ in
        try await newValue(animated)
      }
    }
  }
  #endif
}

extension NavigationTo {

  @_transparent
  public func canPerform(
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Bool {
    self.canPerformCheck(
      file,
      line
    )
  }

  @_transparent
  public func perform(
    animated: Bool = true,
    context: Destination.TransitionContext,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async throws {
    try await self.performAnimated(
      animated,
      context,
      file,
      line
    )
  }

  @_transparent
  public func performCatching(
    animated: Bool = true,
    context: Destination.TransitionContext,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async {
    await consumingErrors(
      errorDiagnostics: "Navigation perform failed!",
      {
        try await self.performAnimated(
          animated,
          context,
          file,
          line
        )
      },
      file: file,
      line: line
    )
  }

  @_transparent
  public func perform(
    animated: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async throws
  where Destination.TransitionContext == Void {
    try await self.performAnimated(
      animated,
      Void(),
      file,
      line
    )
  }

  @_transparent
  public func performCatching(
    animated: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async
  where Destination.TransitionContext == Void {
    await consumingErrors(
      errorDiagnostics: "Navigation perform failed!",
      {
        try await self.performAnimated(
          animated,
          Void(),
          file,
          line
        )
      },
      file: file,
      line: line
    )
  }

  @_transparent
  public func revert(
    animated: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async throws {
    try await self.revertAnimated(
      animated,
      file,
      line
    )
  }

  @_transparent
  public func revertCatching(
    animated: Bool = true,
    file: StaticString = #fileID,
    line: UInt = #line
  ) async {
    await consumingErrors(
      errorDiagnostics: "Navigation revert failed!",
      {
        try await self.revertAnimated(
          animated,
          file,
          line
        )
      },
      file: file,
      line: line
    )
  }
}

extension NavigationTo {

  public static func replaceRoot<DestinationView>(
    with: DestinationView.Type = DestinationView.self,
    createNavigationStack: Bool,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let rootNavigation: RootNavigation = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let view = try prepareTransitionView(features, context)
          let item = AnyNavigationItem(id: Destination.identifier) { view }
          rootNavigation.state.setRoot(item, withNavigationStack: createNavigationStack)
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          assertionFailure("You cannot revert a root replacement navigation!")
        }

        @MainActor func canPerform(
          file: StaticString,
          line: UInt
        ) -> Bool {
          rootNavigation.state.currentRoot?.id != Destination.identifier
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:),
          canPerformCheck: canPerform(file:line:)
        )
      }
    )
  }

  public static func replaceRoot<DestinationView>(
    with: DestinationView.Type,
    createNavigationStack: Bool = false
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.replaceRoot(
      with: DestinationView.self,
      createNavigationStack: createNavigationStack,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

}

extension NavigationTo {

  /// Uses NavigationStateRegistry to find the active navigation state at runtime.
  public static func pushTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let registry: NavigationStateRegistry = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else {
            throw
              InternalInconsistency
              .error(
                "No active NavigationState found!",
                file: file,
                line: line
              )
              .asAssertionFailure()
          }
          let view = try prepareTransitionView(features, context)
          let item = AnyNavigationItem(id: Destination.identifier) {
            view
          }
          try navigationState.push(item, unique: Destination.isUnique)
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else { return }
          navigationState.dismiss(with: Destination.identifier)
        }

        @MainActor func canPerform(
          file: StaticString,
          line: UInt
        ) -> Bool {
          guard let navigationState: NavigationState = registry.activeState()
          else { return false }
          return !Destination.isUnique || !navigationState.exists(with: Destination.identifier)
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:),
          canPerformCheck: canPerform(file:line:)
        )
      }
    )
  }

  /// SwiftUI-native push navigation with automatic controller instantiation.
  public static func pushTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.pushTransition(
      to: DestinationView.self,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

  public static func sheetPresentationTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let registry: NavigationStateRegistry = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else {
            throw
              InternalInconsistency
              .error(
                "No active NavigationState found!",
                file: file,
                line: line
              )
              .asAssertionFailure()
          }
          let view = try prepareTransitionView(features, context)
          let item = AnyNavigationItem(id: Destination.identifier) {
            view
          }
          try navigationState.presentSheet(item, unique: Destination.isUnique)
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else { return }
          navigationState.dismiss(with: Destination.identifier)
        }

        @MainActor func canPerform(
          file: StaticString,
          line: UInt
        ) -> Bool {
          guard let navigationState: NavigationState = registry.activeState()
          else { return false }
          return !Destination.isUnique || !navigationState.exists(with: Destination.identifier)
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:),
          canPerformCheck: canPerform(file:line:)
        )
      }
    )
  }

  public static func sheetPresentationTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.sheetPresentationTransition(
      to: DestinationView.self,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

  @_disfavoredOverload
  public static func sheetPresentationTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Void {
    Self.sheetPresentationTransition(
      to: DestinationView.self,
      { features, _ in
        try DestinationView(controller: features.instance())
      }
    )
  }

  public static func partialSheetPresentationTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let registry: NavigationStateRegistry = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else {
            throw
              InternalInconsistency
              .error(
                "No active NavigationState found!",
                file: file,
                line: line
              )
              .asAssertionFailure()
          }
          let view = try prepareTransitionView(features, context)
          let item = AnyNavigationItem(id: Destination.identifier) {
            view
          }
          try navigationState.presentPartialSheet(item, unique: Destination.isUnique)
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else { return }
          navigationState.dismiss(with: Destination.identifier)
        }

        @MainActor func canPerform(
          file: StaticString,
          line: UInt
        ) -> Bool {
          guard let navigationState: NavigationState = registry.activeState()
          else { return false }
          return !Destination.isUnique || !navigationState.exists(with: Destination.identifier)
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:),
          canPerformCheck: canPerform(file:line:)
        )
      }
    )
  }

  public static func partialSheetPresentationTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.partialSheetPresentationTransition(
      to: DestinationView.self,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

  /// SwiftUI-native alert presentation.
  public static func alertPresentationTransition<Alert>(
    using: Alert.Type = Alert.self,
    _ prepare: @escaping @MainActor (Features, Destination.TransitionContext) throws -> Alert
  ) -> FeatureLoader
  where Alert: AlertController {
    .disposable(
      Self.self,
      load: { features in
        let registry: NavigationStateRegistry = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else {
            throw
              InternalInconsistency
              .error(
                "No active NavigationState found!",
                file: file,
                line: line
              )
              .asAssertionFailure()
          }
          let alert: Alert = try prepare(features, context)
          let alertItem = AlertItem(
            id: Destination.identifier,
            title: alert.title.string(),
            message: alert.message?.string(),
            actions: alert.actions.map { action in
              SwiftUIAlertAction(
                title: action.title.string(),
                role: action.role.swiftUIAlertActionRole,
                action: action.action
              )
            }
          )
          navigationState.presentAlert(alertItem)
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          guard let navigationState: NavigationState = registry.activeState()
          else { return }
          navigationState.alertDismissed()
        }

        @MainActor func canPerform(
          file: StaticString,
          line: UInt
        ) -> Bool {
          guard let navigationState: NavigationState = registry.activeState()
          else { return false }
          return !Destination.isUnique || !navigationState.exists(with: Destination.identifier)
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:),
          canPerformCheck: canPerform(file:line:)
        )
      }
    )
  }

  public static func alertPresentationTransition<Alert>(
    using: Alert.Type = Alert.self
  ) -> FeatureLoader
  where Alert: AlertController, Destination.TransitionContext == Alert.Context {
    Self.alertPresentationTransition(
      using: Alert.self,
      { features, context in
        try Alert(
          with: context,
          using: features
        )
      }
    )
  }

  public static func popToRoot() -> FeatureLoader {
    .disposable(Self.self) { features in
      let registry: NavigationStateRegistry = try features.instance()

      @MainActor @Sendable func perform(
        animated: Bool,
        context: Destination.TransitionContext,
        file: StaticString,
        line: UInt
      ) async throws {
        guard let navigationState: NavigationState = registry.activeState()
        else { return }
        navigationState.popToRoot()
      }

      @MainActor @Sendable func revert(
        animated: Bool,
        file: StaticString,
        line: UInt
      ) async throws {
        assertionFailure("Can't revert pop to root!")
      }

      @MainActor func canPerform(
        file: StaticString,
        line: UInt
      ) -> Bool {
        true
      }

      return .init(
        performAnimated: perform(animated:context:file:line:),
        revertAnimated: revert(animated:file:line:),
        canPerformCheck: canPerform(file:line:)
      )
    }
  }
}
