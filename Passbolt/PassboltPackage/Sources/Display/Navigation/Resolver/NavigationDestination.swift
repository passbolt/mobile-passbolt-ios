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

public protocol NavigationDestination {

  associatedtype TransitionContext = Void

  // Used to determine if there can be more than one view
  // for the same transition (transition done more than once).
  // This can be required in case of "nested details".
  // Reverting navigation with "nested details" reverts
  // only latest/topmost element. Reverting to first
  // or any in the middle is not supported.
  // Such a transition requires preparing dedicated
  // additional destination to refer to.
  // Default implementation is true (unique).
  static var isUnique: Bool { get }
  static var identifier: NavigationDestinationIdentifier { get }
}

extension NavigationDestination {

  public static var isUnique: Bool { true }

  public static var identifier: NavigationDestinationIdentifier {
    .init(Self.self)
  }
}
