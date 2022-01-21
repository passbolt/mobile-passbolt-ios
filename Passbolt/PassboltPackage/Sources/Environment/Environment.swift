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

import Commons
import Crypto

public protocol EnvironmentElement {}

extension EnvironmentElement {

  fileprivate static var environmentIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
}

public struct Environment {

  private var environment: Dictionary<ObjectIdentifier, EnvironmentElement> = .init()

  public init(_ elements: EnvironmentElement...) {
    var environment: Dictionary<ObjectIdentifier, EnvironmentElement> = .init()
    environment.reserveCapacity(elements.count)
    elements.forEach { element in
      environment[type(of: element).environmentIdentifier] = element
    }
    self.environment = environment
  }
}

extension Environment {

  public func element<E>(
    _ elementType: E.Type = E.self
  ) -> E where E: EnvironmentElement {
    if let element: E = environment[elementType.environmentIdentifier] as? E {
      return element
    }
    else {
      unreachable("Trying to use uninitialized environment element")
    }
  }

  public func contains<E>(
    _ elementType: E.Type = E.self
  ) -> Bool where E: EnvironmentElement {
    environment[elementType.environmentIdentifier] is E
  }

  public mutating func use<E>(
    _ element: E
  ) where E: EnvironmentElement {
    environment[type(of: element).environmentIdentifier] = element
  }
}
