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

import AegithalosCocoa
import Commons
import SwiftUI

@MainActor
public struct SelectionListView<ItemID>: View
where ItemID: Hashable {

  private let items: Array<Item>
  private let selectedItems: Set<Item.ID>
  private let selection: @MainActor (ItemID) -> Void

  public init(
    items: Array<Item>,
    selectedItems: Set<Item.ID>,
    selection: @MainActor @escaping (AnyHashable) -> Void
  ) {
    self.selection = selection
    self.items = items
    self.selectedItems = selectedItems
  }

  public var body: some View {
    VStack(spacing: 8) {
      ForEach(self.items) { (item: Item) in
        HStack(spacing: 0) {
          Image(named: item.iconName)
            .aspectRatio(
              1,
              contentMode: .fit
            )
            .frame(width: 24)
            .padding(4)

          Text(displayable: item.title)
            .text(
              font: .inter(
                ofSize: 14,
                weight: .semibold
              ),
              color: .passboltPrimaryText
            )
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
            .padding(4)

          let itemSelected: Bool = self.selectedItems.contains(item.id)
          Image(
            named: itemSelected
              ? .circleSelected
              : .circleUnselected
          )
          .aspectRatio(
            1,
            contentMode: .fit
          )
          .foregroundColor(
            itemSelected
              ? .passboltPrimaryBlue
              : .passboltDivider
          )
          .frame(width: 24)
          .padding(4)
        }
        .frame(
          maxWidth: .infinity,
          minHeight: 32
        )
      }
    }
  }
}

extension SelectionListView {

  public struct Item {

    public var id: ItemID
    public var iconName: ImageNameConstant
    public var title: DisplayableString
  }
}

extension SelectionListView.Item: Identifiable {}

#if DEBUG

internal struct SelectionListView_Previews: PreviewProvider {

  internal static var previews: some View {
    let allItems: Array<SelectionListView<AnyHashable>.Item> =
      [
        .init(
          id: UUID(),
          iconName: .permissionReadIcon,
          title: "Read"
        ),
        .init(
          id: UUID(),
          iconName: .permissionOwnIcon,
          title: "Own"
        ),
      ]

    SelectionListView(
      items: allItems,
      selectedItems: [allItems.randomElement()!.id],
      selection: { _ in }
    )
  }
}
#endif
