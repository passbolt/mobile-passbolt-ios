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

import Foundation

/// Feature that tracks NavigationState instances and determines which one is currently active.
/// This mirrors how legacy UIKit navigation finds the active UINavigationController at runtime.
public struct NavigationStateRegistry {

  public var register: @MainActor (NavigationState) -> Void
  public var unregister: @MainActor (NavigationState) -> Void
  public var setActive: @MainActor (NavigationState) -> Void
  public var deactivate: @MainActor (NavigationState) -> Void
  public var activeState: @MainActor () -> NavigationState?
  public var cleanup: @MainActor () -> Void
}

extension NavigationStateRegistry: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      register: unimplemented1(),
      unregister: unimplemented1(),
      setActive: unimplemented1(),
      deactivate: unimplemented1(),
      activeState: unimplemented0(),
      cleanup: unimplemented0()
    )
  }
  #endif

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    var registeredStates: Dictionary<ObjectIdentifier, WeakBox<NavigationState>> = [:]
    var activeStateID: ObjectIdentifier? = .none

    return .init(
      register: { (state: NavigationState) in
        let id: ObjectIdentifier = ObjectIdentifier(state)
        registeredStates[id] = WeakBox(state)
      },
      unregister: { (state: NavigationState) in
        let id: ObjectIdentifier = ObjectIdentifier(state)
        registeredStates.removeValue(forKey: id)
        if activeStateID == id {
          activeStateID = .none
        }
      },
      setActive: { (state: NavigationState) in
        let id: ObjectIdentifier = ObjectIdentifier(state)
        // Auto-register if not already registered
        if registeredStates[id] == nil {
          registeredStates[id] = WeakBox(state)
        }
        activeStateID = id
      },
      deactivate: { (state: NavigationState) in
        let id: ObjectIdentifier = ObjectIdentifier(state)
        if activeStateID == id {
          activeStateID = .none
        }
      },
      activeState: {
        guard let id: ObjectIdentifier = activeStateID else { return .none }
        return registeredStates[id]?.value
      },
      cleanup: {
        registeredStates = registeredStates.filter { $0.value.value != nil }
      }
    )
  }
}

extension FeaturesRegistry {

  public mutating func useLiveNavigationStateRegistry() {
    self.use(
      .lazyLoaded(
        NavigationStateRegistry.self,
        load: NavigationStateRegistry.load(features:)
      )
    )
  }
}

/// Weak reference wrapper to avoid retain cycles.
private final class WeakBox<T: AnyObject> {
  weak var value: T?

  init(_ value: T) {
    self.value = value
  }
}
