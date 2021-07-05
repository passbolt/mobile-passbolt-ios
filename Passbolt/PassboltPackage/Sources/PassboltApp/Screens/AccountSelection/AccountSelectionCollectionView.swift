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

import UICommons

internal final class AccountSelectionCollectionView: CollectionView<SingleSection, AccountSelectionListItem> {

  internal lazy var accountTapPublisher: AnyPublisher<AccountSelectionCellItem, Never> =
    accountTapSubject.eraseToAnyPublisher()
  internal lazy var addAccountPublisher: AnyPublisher<Void, Never> =
    addAccountTapSubject.eraseToAnyPublisher()
  internal lazy var removeAccountPublisher: AnyPublisher<AccountSelectionCellItem, Never> =
    removeSubject.eraseToAnyPublisher()

  private let accountTapSubject: PassthroughSubject<AccountSelectionCellItem, Never> = .init()
  private let addAccountTapSubject: PassthroughSubject<Void, Never> = .init()
  private let removeSubject: PassthroughSubject<AccountSelectionCellItem, Never> = .init()

  internal init(layout: UICollectionViewLayout) {
    super.init(
      layout: layout,
      cells: [
        AccountSelectionCell.self,
        AccountSelectionAddAccountCell.self,
      ],
      supplementaryViews: [CollectionViewSeparator.self]
    )
    setup()
  }

  override internal func setupCell(
    for item: AccountSelectionListItem,
    in section: SingleSection,
    at indexPath: IndexPath
  ) -> CollectionViewCell? {

    switch item {
    case let .account(accountItem):
      let cell: AccountSelectionCell =
        dequeueReusableCell(
          withReuseIdentifier: AccountSelectionCell.reuseIdentifier,
          for: indexPath
        ) as? AccountSelectionCell ?? .init()

      cell.setup(
        from: accountItem,
        tapAction: { [weak self] in
          self?.accountTapSubject.send(accountItem)
        },
        removeAction: { [weak self] in
          self?.removeSubject.send(accountItem)
        }
      )

      return cell

    case let .addAccount(addAccountItem):
      let cell: AccountSelectionAddAccountCell =
        dequeueReusableCell(
          withReuseIdentifier: AccountSelectionAddAccountCell.reuseIdentifier,
          for: indexPath
        ) as? AccountSelectionAddAccountCell ?? .init()

      cell.setup(
        from: addAccountItem,
        tapAction: { [weak self] in
          self?.addAccountTapSubject.send()
        }
      )

      return cell
    }
  }

  override internal func setupSupplementaryView(
    _ kind: String,
    for section: SingleSection,
    at indexPath: IndexPath
  ) -> CollectionReusableView? {
    let supplementaryView: CollectionViewSeparator =
      dequeueReusableSupplementaryView(
        ofKind: CollectionViewSeparator.reuseIdentifier,
        withReuseIdentifier: CollectionViewSeparator.reuseIdentifier,
        for: indexPath
      ) as? CollectionViewSeparator ?? .init()

    return supplementaryView
  }
}
