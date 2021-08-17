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

internal final class ResourcesListView: CollectionView<SingleSection, ResourcesListViewItem> {

  internal var addTapPublisher: AnyPublisher<Void, Never> {
    addTapSubject.eraseToAnyPublisher()
  }
  internal var itemTapPublisher: AnyPublisher<ListViewResource, Never> {
    itemTapSubject.eraseToAnyPublisher()
  }
  internal var itemMenuTapPublisher: AnyPublisher<ListViewResource, Never> {
    itemMenuTapSubject.eraseToAnyPublisher()
  }

  private let addTapSubject: PassthroughSubject<Void, Never> = .init()
  private var itemTapSubject: PassthroughSubject<ListViewResource, Never> = .init()
  private var itemMenuTapSubject: PassthroughSubject<ListViewResource, Never> = .init()

  internal init() {
    super.init(
      layout: .resourcesList(),
      cells: [
        ResourcesListAddCell.self,
        ResourcesListResourceCell.self,
      ]
    )
  }

  override internal func setup() {
    mut(self) {
      .combined(
        .set(\.dynamicBackgroundColor, to: .background),
        .set(\.keyboardDismissMode, to: .onDrag)
      )
    }

    self.emptyStateView = EmptyStateView()
  }

  override internal func setupCell(
    for item: ResourcesListViewItem,
    in section: SingleSection,
    at indexPath: IndexPath
  ) -> CollectionViewCell? {
    switch item {
    case .add:
      let cell: ResourcesListAddCell = dequeueOrMakeReusableCell(at: indexPath)

      cell.setup(
        tapAction: { [weak self] in
          self?.addTapSubject.send()
        }
      )

      return cell

    case let .resource(resource):
      let cell: ResourcesListResourceCell = dequeueOrMakeReusableCell(at: indexPath)

      cell.setup(
        from: resource,
        tapAction: { [weak self] in
          self?.itemTapSubject.send(resource)
        },
        menuTapAction: { [weak self] in
          self?.itemMenuTapSubject.send(resource)
        }
      )

      return cell
    }
  }
}
