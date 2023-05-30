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

public struct NavigationTo<Destination>
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
}

extension NavigationTo: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      performAnimated: unimplemented4(),
      revertAnimated: unimplemented3()
    )
  }

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
  @Sendable public func perform(
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
  @Sendable public func perform(
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
  @Sendable public func revert(
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
}

extension NavigationTo {

  public static func legacyPushTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor = try UIHostingController(
            rootView: prepareTransitionView(features, context)
          )
          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .push(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyPushTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.legacyPushTransition(
      to: DestinationView.self,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

  public static func legacySheetPresentationTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor = try UIHostingController(
            rootView: prepareTransitionView(features, context)
          )
          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .present(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacySheetPresentationTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Void {
    Self.legacySheetPresentationTransition(
      to: DestinationView.self,
      { features, _ in
        try DestinationView(controller: features.instance())
      }
    )
  }

  public static func legacySheetPresentationTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws ->
      DestinationViewController
  ) -> FeatureLoader
  where DestinationViewController: UIComponent {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor = try prepareTransitionView(features, context)
          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .present(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacySheetPresentationTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self,
    context: DestinationViewController.Controller.Context
  ) -> FeatureLoader
  where DestinationViewController: UIComponent {
    self.legacySheetPresentationTransition(
      toLegacy: DestinationViewController.self,
      { features, _ in
        var features: Features = features
        let cancellables: Cancellables = .init()

        let controller: DestinationViewController.Controller = try .instance(
          in: context,
          with: &features,
          cancellables: cancellables
        )

        return
          DestinationViewController
          .instance(
            using: controller,
            with: .init(features: features),
            cancellables: cancellables
          )
      }
    )
  }

  public static func legacySheetPresentationTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self
  ) -> FeatureLoader
  where
    DestinationViewController: UIComponent,
    DestinationViewController.Controller.Context == Destination.TransitionContext
  {
    self.legacySheetPresentationTransition(
      toLegacy: DestinationViewController.self,
      { features, context in
        var features: Features = features
        let cancellables: Cancellables = .init()

        let controller: DestinationViewController.Controller = try .instance(
          in: context,
          with: &features,
          cancellables: cancellables
        )

        return
          DestinationViewController
          .instance(
            using: controller,
            with: .init(features: features),
            cancellables: cancellables
          )
      }
    )
  }

  public static func legacyPartialSheetPresentationTransition<DestinationView>(
    to: DestinationView.Type = DestinationView.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws -> DestinationView
  ) -> FeatureLoader
  where DestinationView: ControlledView {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor
          if #available(iOS 16.0, *) {
            anchor = UIHostingController(
              rootView: try prepareTransitionView(features, context)
            )
            anchor.sheetPresentationController?.detents = [
              navigationResolver.dynamicLegacySheetDetent(for: anchor)
            ]
          }
          else {
            anchor = try PartialSheetViewController(
              wrapping: UIHostingController(
                rootView: prepareTransitionView(features, context)
              )
            )
          }

          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .present(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyPartialSheetPresentationTransition<DestinationView>(
    to: DestinationView.Type
  ) -> FeatureLoader
  where DestinationView: ControlledView, DestinationView.Controller.Context == Destination.TransitionContext {
    Self.legacyPartialSheetPresentationTransition(
      to: DestinationView.self,
      { features, context in
        try DestinationView(controller: features.instance(context: context))
      }
    )
  }

  public static func legacyPartialSheetPresentationTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws ->
      DestinationViewController
  ) -> FeatureLoader
  where DestinationViewController: UIComponent {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor
          if #available(iOS 16.0, *) {
            anchor = try prepareTransitionView(features, context)

            anchor.sheetPresentationController?.detents = [
              navigationResolver.dynamicLegacySheetDetent(for: anchor)
            ]
          }
          else {
            anchor = try PartialSheetViewController(
              wrapping: prepareTransitionView(features, context)
            )
          }

          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .present(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyPartialSheetPresentationTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self
  ) -> FeatureLoader
  where DestinationViewController: UIComponent, DestinationViewController.Controller.Context == Void {
    self.legacyPartialSheetPresentationTransition(
      toLegacy: DestinationViewController.self,
      { features, _ in
        var features: Features = features
        let cancellables: Cancellables = .init()

        let controller: DestinationViewController.Controller = try .instance(
          with: &features,
          cancellables: cancellables
        )

        return
          DestinationViewController
          .instance(
            using: controller,
            with: .init(features: features),
            cancellables: cancellables
          )
      }
    )
  }

  public static func legacyTabSwitch<DestinationViewController>(
    to: DestinationViewController.Type = DestinationViewController.self
  ) -> FeatureLoader
  where DestinationViewController: UIViewController, Destination.TransitionContext == Void {
    .disposable(
      Self.self,
      load: { features in
        precondition(
          Destination.isUnique,
          "Tab switch has to be unique!"
        )

        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .legacyTabSwitch(
              to: DestinationViewController.self,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          throw
            InternalInconsistency
            .error("Invalid navigation - can't revert tab switching!")
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyAlertPresentationTransition<Alert>(
    using: Alert.Type = Alert.self,
    _ prepare: @escaping @MainActor (Features, Destination.TransitionContext) throws -> Alert
  ) -> FeatureLoader
  where Alert: AlertController {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let alert: Alert = try prepare(features, context)
          let anchor: NavigationAnchor = {
            let alertController: UIAlertController = .init(
              title: alert.title.string(),
              message: alert.message?.string(),
              preferredStyle: .alert
            )
            alert.actions
              .forEach { action in
                alertController.addAction(
                  .init(
                    title: action.title.string(),
                    style: action.role.style,
                    handler: { _ in
                      action.action()
                    }
                  )
                )
              }
            return alertController
          }()
          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .present(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyAlertPresentationTransition<Alert>(
    using: Alert.Type = Alert.self
  ) -> FeatureLoader
  where Alert: AlertController, Destination.TransitionContext == Alert.Context {
    Self.legacyAlertPresentationTransition(
      using: Alert.self,
      { features, context in
        try Alert(
          with: context,
          using: features
        )
      }
    )
  }
}

extension NavigationTo {

  public static func legacyPushTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self,
    _ prepareTransitionView: @escaping @MainActor (Features, Destination.TransitionContext) throws ->
      DestinationViewController
  ) -> FeatureLoader
  where DestinationViewController: UIComponent {
    .disposable(
      Self.self,
      load: { features in
        let navigationResolver: NavigationResolver = try features.instance()

        @MainActor @Sendable func isActive() async -> Bool {
          navigationResolver
            .exists(with: Destination.identifier)
        }

        @MainActor @Sendable func perform(
          animated: Bool,
          context: Destination.TransitionContext,
          file: StaticString,
          line: UInt
        ) async throws {
          let anchor: NavigationAnchor = try prepareTransitionView(features, context)
          anchor.destinationIdentifier = Destination.identifier
          try await navigationResolver
            .push(
              anchor,
              unique: Destination.isUnique,
              animated: animated,
              file: file,
              line: line
            )
        }

        @MainActor @Sendable func revert(
          animated: Bool,
          file: StaticString,
          line: UInt
        ) async throws {
          try await navigationResolver
            .dismiss(
              with: Destination.identifier,
              animated: animated,
              file: file,
              line: line
            )
        }

        return .init(
          performAnimated: perform(animated:context:file:line:),
          revertAnimated: revert(animated:file:line:)
        )
      }
    )
  }

  public static func legacyPushTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self,
    context: DestinationViewController.Controller.Context
  ) -> FeatureLoader
  where DestinationViewController: UIComponent {
    self.legacyPushTransition(
      toLegacy: DestinationViewController.self,
      { features, _ in
        var features: Features = features
        let cancellables: Cancellables = .init()

        let controller: DestinationViewController.Controller = try .instance(
          in: context,
          with: &features,
          cancellables: cancellables
        )

        return
          DestinationViewController
          .instance(
            using: controller,
            with: .init(features: features),
            cancellables: cancellables
          )
      }
    )
  }

  public static func legacyPushTransition<DestinationViewController>(
    toLegacy: DestinationViewController.Type = DestinationViewController.self
  ) -> FeatureLoader
  where
    DestinationViewController: UIComponent,
    DestinationViewController.Controller.Context == Destination.TransitionContext
  {
    self.legacyPushTransition(
      toLegacy: DestinationViewController.self,
      { features, context in
        var features: Features = features
        let cancellables: Cancellables = .init()

        let controller: DestinationViewController.Controller = try .instance(
          in: context,
          with: &features,
          cancellables: cancellables
        )

        return
          DestinationViewController
          .instance(
            using: controller,
            with: .init(features: features),
            cancellables: cancellables
          )
      }
    )
  }
}
