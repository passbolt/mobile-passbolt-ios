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
import ObjectiveC

public struct UIComponentFactory {

  private let features: FeatureFactory

  public init(features: FeatureFactory) {
    self.features = features
  }
}

extension UIComponentFactory {

  @MainActor public func instance<Component>(
    of component: Component.Type = Component.self,
    in context: Component.Controller.Context
  ) -> Component
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let component: Component = .instance(
      using: .instance(
        in: context,
        with: features,
        cancellables: cancellables
      ),
      with: self
    )
    component.cancellables = cancellables
    return component
  }

  @MainActor public func instance<Component>(
    of component: Component.Type = Component.self
  ) -> Component
  where Component: UIComponent, Component.Controller.Context == Void {
    let cancellables: Cancellables = .init()
    let component: Component = .instance(
      using: .instance(
        with: features,
        cancellables: cancellables
      ),
      with: self
    )
    component.cancellables = cancellables
    return component
  }
}

extension UIComponent {

  public fileprivate(set) var cancellables: Cancellables {
    get {
      let stored: Cancellables? =
        objc_getAssociatedObject(
          self,
          &cancellablesAssociationKey
        ) as? Cancellables

      if let stored: Cancellables = stored {
        return stored
      }
      else {
        let newValue: Cancellables = .init()
        objc_setAssociatedObject(
          self,
          &cancellablesAssociationKey,
          newValue,
          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return newValue
      }
    }
    set {
      let stored: Cancellables? =
        objc_getAssociatedObject(
          self,
          &cancellablesAssociationKey
        ) as? Cancellables
      if let stored: Cancellables = stored {
        objc_setAssociatedObject(
          self,
          &cancellablesAssociationKey,
          Cancellables(extend: stored, newValue),
          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
      }
      else {
        objc_setAssociatedObject(
          self,
          &cancellablesAssociationKey,
          newValue,
          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
      }
    }
  }
}

private var cancellablesAssociationKey: Int = 0
