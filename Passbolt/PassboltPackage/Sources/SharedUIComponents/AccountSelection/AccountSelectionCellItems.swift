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

public enum AccountSelectionListItem: Hashable {

  case account(AccountSelectionCellItem)
  case addAccount(AccountSelectionAddAccountCellItem)

  public static func == (
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

public struct AccountSelectionCellItem: Hashable {

  public var account: Account
  public var title: String
  public var subtitle: String
  public var isCurrentAccount: Bool
  public var imagePublisher: AnyPublisher<Data?, Never>?
  public var listModePublisher: AnyPublisher<AccountSelectionListMode, Never>

  public init(
    account: Account,
    title: String,
    subtitle: String,
    isCurrentAccount: Bool,
    imagePublisher: AnyPublisher<Data?, Never>?,
    listModePublisher: AnyPublisher<AccountSelectionListMode, Never>
  ) {
    self.account = account
    self.title = title
    self.subtitle = subtitle
    self.isCurrentAccount = isCurrentAccount
    self.imagePublisher = imagePublisher
    self.listModePublisher = listModePublisher
  }

  public static func == (
    lhs: AccountSelectionCellItem,
    rhs: AccountSelectionCellItem
  ) -> Bool {
    lhs.account == rhs.account
      && lhs.title == rhs.title
      && lhs.subtitle == rhs.subtitle
      && lhs.isCurrentAccount == rhs.isCurrentAccount
      && ((lhs.imagePublisher == nil && rhs.imagePublisher == nil)
        || (lhs.imagePublisher != nil && rhs.imagePublisher != nil))
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(account)
    hasher.combine(title)
    hasher.combine(subtitle)
    hasher.combine(isCurrentAccount)
    hasher.combine(imagePublisher != nil)
  }
}

public struct AccountSelectionAddAccountCellItem: Hashable {

  internal let title: String

  public static func == (
    lhs: AccountSelectionAddAccountCellItem,
    rhs: AccountSelectionAddAccountCellItem
  ) -> Bool {
    lhs.title == rhs.title
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(title)
  }
}

extension AccountSelectionAddAccountCellItem {

  public static let `default`: Self = .init(
    title: NSLocalizedString(
      "account.selection.add.account.footer.title",
      bundle: .commons,
      comment: ""
    )
  )
}
