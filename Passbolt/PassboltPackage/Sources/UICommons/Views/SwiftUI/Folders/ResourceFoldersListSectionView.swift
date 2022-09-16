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

public struct ResourceFoldersListSectionView: View {

  private let title: DisplayableString?
  private let folders: Array<ResourceFolderListItemDSV>
  private let tapAction: (ResourceFolder.ID) -> Void

  public init(
    title: DisplayableString? = .none,
    folders: Array<ResourceFolderListItemDSV>,
    tapAction: @escaping (ResourceFolder.ID) -> Void
  ) {
    self.title = title
    self.folders = folders
    self.tapAction = tapAction
  }

  public var body: some View {
    if !self.folders.isEmpty {
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
          self.folders,
          id: \ResourceFolderListItemDSV.id
        ) { item in
          ResourceFolderListItemView(
            name: item.name,
            shared: item.shared,
            contentCount: item.contentCount,
            action: {
              self.tapAction(item.id)
            }
          )
        }
      }
      .listSectionSeparator(.hidden)
      .backgroundColor(.passboltBackground)
    }  // else there is no section
  }
}
