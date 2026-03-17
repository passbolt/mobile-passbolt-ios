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

import SwiftUI

/// Observable object managing root-level navigation state.
/// Used for swapping the entire root view (e.g., splash -> home, home -> authorization).
@MainActor
public final class RootNavigationState: ObservableObject {

  @Published public var currentRoot: AnyNavigationItem? = nil
  @Published public var useNavigationStack: Bool = false

  /// Signal that increments when views should re-activate their navigation state.
  /// Views observe this to re-set their NavigationState as active after restoration.
  @Published public var reactivationSignal: Int = 0

  /// The navigation state used by NavigationContainer when useNavigationStack is true.
  /// Owned by RootNavigationState to ensure it's set as active immediately when root changes.
  public let navigationState: NavigationState = NavigationState()

  private let activateNavigationState: @MainActor (NavigationState) -> Void
  private let deactivateNavigationState: @MainActor (NavigationState) -> Void

  internal init(
    activateNavigationState: @escaping @MainActor (NavigationState) -> Void,
    deactivateNavigationState: @escaping @MainActor (NavigationState) -> Void
  ) {
    self.activateNavigationState = activateNavigationState
    self.deactivateNavigationState = deactivateNavigationState
  }

  /// Sets the root view with an optional navigation stack wrapper.
  /// - Parameters:
  ///   - item: The navigation item to set as root.
  ///   - withNavigationStack: Whether to wrap the root in a NavigationContainer.
  public func setRoot(_ item: AnyNavigationItem, withNavigationStack: Bool) {
    let isSameRoot: Bool = currentRoot?.id == item.id

    // Only clear navigation path when switching to a different root
    if !isSameRoot {
      navigationState.popToRoot()
    }

    self.useNavigationStack = withNavigationStack
    self.currentRoot = item

    // Set navigation state as active immediately when using navigation stack.
    // When not using navigation stack, signal views to re-activate their own state.
    if withNavigationStack {
      activateNavigationState(navigationState)
    }
    else {
      // Signal tabs/views to re-activate their navigation state
      self.reactivationSignal += 1
    }
  }

  /// Clears the current root view.
  public func clearRoot() {
    navigationState.popToRoot()
    deactivateNavigationState(navigationState)
    self.currentRoot = nil
    self.useNavigationStack = false
  }
}

// MARK: - RootNavigation Feature

/// Feature wrapper for RootNavigationState that integrates with the Features DI container.
public struct RootNavigation {

  public let state: RootNavigationState
}

extension RootNavigation: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    MainActor.assumeIsolated {
      .init(
        state: RootNavigationState(
          activateNavigationState: unimplemented1(),
          deactivateNavigationState: unimplemented1()
        )
      )
    }
  }
  #endif

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let registry: NavigationStateRegistry = try features.instance()
    let state: RootNavigationState = RootNavigationState(
      activateNavigationState: registry.setActive,
      deactivateNavigationState: registry.deactivate
    )
    return .init(state: state)
  }
}

extension FeaturesRegistry {

  public mutating func useLiveRootNavigation() {
    self.use(
      .lazyLoaded(
        RootNavigation.self,
        load: RootNavigation.load(features:)
      )
    )
  }
}
