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

public enum ConfirmPermissionsMode: Equatable, Sendable {

  /// Creating a resource inside a shared folder - editable only when the operator owns that folder.
  case create(editable: Bool)
  /// Editing a shared resource - editable only when the operator is an owner.
  case edit(editable: Bool)
  /// Sharing an existing resource - always editable; only reachable for a resource the operator may share.
  case share

  public var isEditable: Bool {
    switch self {
    case .create(let editable), .edit(let editable):
      return editable

    case .share:
      return true
    }
  }

  public var title: DisplayableString {
    switch self {
    case .create, .edit:
      return .localized(key: "resource.permission.confirm.title")

    case .share:
      return .localized(key: "resource.permission.edit.list.title")
    }
  }

  public var ownershipRule: ConfirmPermissionsOwnershipRule? {
    guard self.isEditable
    else { return .none }
    switch self {
    case .edit:
      return .operatorRemainsOwner

    case .create, .share:
      return .anyOwnerRemains
    }
  }
}

/// What a confirmation refuses to apply, ownership-wise.
public enum ConfirmPermissionsOwnershipRule: Equatable, Sendable {

  /// The operator stays an owner - directly or through a group holding ownership.
  case operatorRemainsOwner
  /// Somebody has to own the resource, whoever it is.
  case anyOwnerRemains
}
