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

import Accounts
import UICommons

internal enum AccountSelectionListItem: Hashable {

  case account(AccountSelectionCellItem)
  case addAccount(AccountSelectionAddAccountCellItem)

  internal static func == (
    lhs: AccountSelectionListItem,
    rhs: AccountSelectionListItem
  ) -> Bool {
    switch (lhs, rhs) {
    case let (.account(lhsItem), .account(rhsItem)):
      return lhsItem == rhsItem
    case let (.addAccount(lhsItem), .addAccount(rhsItem)):
      return lhsItem == rhsItem

    case _:
      return false
    }
  }
}

internal struct AccountSelectionCellItem: Hashable {

  internal var localID: Account.LocalID
  internal var title: String
  internal var subtitle: String
  internal var imagePublisher: AnyPublisher<Data?, Never>?
  internal var listModePublisher: AnyPublisher<AccountSelectionController.ListMode, Never>

  internal static func == (
    lhs: AccountSelectionCellItem,
    rhs: AccountSelectionCellItem
  ) -> Bool {
    lhs.title == rhs.title
      && lhs.subtitle == rhs.subtitle
      && ((lhs.imagePublisher == nil && rhs.imagePublisher == nil)
        || (lhs.imagePublisher != nil && rhs.imagePublisher != nil))
  }

  internal func hash(into hasher: inout Hasher) {
    hasher.combine(localID)
    hasher.combine(title)
    hasher.combine(subtitle)
  }
}

internal struct AccountSelectionAddAccountCellItem: Hashable {

  internal let title: String

  internal static func == (
    lhs: AccountSelectionAddAccountCellItem,
    rhs: AccountSelectionAddAccountCellItem
  ) -> Bool {
    lhs.title == rhs.title
  }

  internal func hash(into hasher: inout Hasher) {
    hasher.combine(title)
  }
}

extension AccountSelectionAddAccountCellItem {

  internal static let `default`: Self = .init(
    title: NSLocalizedString("account.selection.add.account.footer.title", comment: "")
  )
}
