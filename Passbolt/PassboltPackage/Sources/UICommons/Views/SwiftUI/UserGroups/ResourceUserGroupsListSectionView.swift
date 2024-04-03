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

import CommonModels
import SwiftUI

public struct ResourceUserGroupsListSectionView: View {

  private let title: DisplayableString?
  private let userGroups: Array<ResourceUserGroupListItemDSV>
  private let tapAction: (UserGroup.ID) async throws -> Void

  public init(
    title: DisplayableString? = .none,
    userGroups: Array<ResourceUserGroupListItemDSV>,
    tapAction: @escaping (UserGroup.ID) async throws -> Void
  ) {
    self.title = title
    self.userGroups = userGroups
    self.tapAction = tapAction
  }

  public var body: some View {
    if !self.userGroups.isEmpty {
      Section {
        if let title: DisplayableString = self.title {
          Text(displayable: title)
            .text(
              font: .inter(
                ofSize: 14,
                weight: .semibold
              ),
              color: .passboltPrimaryText
            )
            .padding(
              leading: 16,
              trailing: 16
            )
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(.plain)
        }  // else skip title

        ForEach(
          self.userGroups,
          id: \ResourceUserGroupListItemDSV.id
        ) { item in
          ResourceUserGroupListItemView(
            name: item.name,
            contentCount: item.contentCount,
            action: {
              try await self.tapAction(item.id)
            }
          )
        }
      }
      .listSectionSeparator(.hidden)
      .backgroundColor(.passboltBackground)
    }  // else there is no section
  }
}
