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

public struct ResourceFolderContentView: View {

  private let isSearchResult: Bool
  private let directFolders: Array<ResourceFolderListItemDSV>
  private let nestedFolders: Array<ResourceFolderListItemDSV>
  private let directResources: Array<ResourceListItemDSV>
  private let nestedResources: Array<ResourceListItemDSV>
  private let contentEmpty: Bool
  private let directContentEmpty: Bool
  private let nestedContentEmpty: Bool
  private let refreshAction: () async -> Void
  private let createAction: (() -> Void)?
  private let folderTapAction: (ResourceFolder.ID) -> Void
  private let resourceTapAction: (Resource.ID) -> Void
  private let resourceMenuAction: ((Resource.ID) -> Void)?

  public init(
    isSearchResult: Bool,
    directFolders: Array<ResourceFolderListItemDSV>,
    nestedFolders: Array<ResourceFolderListItemDSV>,
    directResources: Array<ResourceListItemDSV>,
    nestedResources: Array<ResourceListItemDSV>,
    refreshAction: @escaping () async -> Void,
    createAction: (() -> Void)?,
    folderTapAction: @escaping (ResourceFolder.ID) -> Void,
    resourceTapAction: @escaping (Resource.ID) -> Void,
    resourceMenuAction: ((Resource.ID) -> Void)?
  ) {
    self.isSearchResult = isSearchResult
    self.directFolders = directFolders
    self.nestedFolders = nestedFolders
    self.directResources = directResources
    self.nestedResources = nestedResources
    self.contentEmpty =
      directFolders.isEmpty
      && directResources.isEmpty
      && nestedFolders.isEmpty
      && nestedResources.isEmpty
    self.directContentEmpty =
      directFolders.isEmpty
      && directResources.isEmpty
    self.nestedContentEmpty =
      nestedFolders.isEmpty
      && nestedResources.isEmpty
    self.refreshAction = refreshAction
    self.createAction = createAction
    self.folderTapAction = folderTapAction
    self.resourceTapAction = resourceTapAction
    self.resourceMenuAction = resourceMenuAction
  }

  public var body: some View {
    List {
      if let createAction: () -> Void = self.createAction {
        ResourceListAddView(action: createAction)
      }  // else no create row

      if self.contentEmpty {
        // empty
        EmptyListView()
      }
      else if self.isSearchResult {
        if !self.directContentEmpty {
          Text(displayable: .localized("home.presentation.mode.folders.explorer.search.direct.results"))
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

          ResourceFoldersListSectionView(
            folders: self.directFolders,
            tapAction: self.folderTapAction
          )

          ResourcesListSectionView(
            resources: self.directResources,
            tapAction: self.resourceTapAction,
            menuAction: self.resourceMenuAction
          )
        }  // else skip direct content

        if !self.nestedContentEmpty {
          if !self.directContentEmpty {
            ListDividerView()
          }  // else no divider

          Text(displayable: .localized("home.presentation.mode.folders.explorer.search.nested.results"))
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

          ResourceFoldersListSectionView(
            folders: self.nestedFolders,
            tapAction: self.folderTapAction
          )
          ResourcesListSectionView(
            resources: self.nestedResources,
            tapAction: self.resourceTapAction,
            menuAction: self.resourceMenuAction
          )
        }  // else skip nested content
      }
      else {
        ResourceFoldersListSectionView(
          folders: self.directFolders,
          tapAction: self.folderTapAction
        )

        ResourcesListSectionView(
          resources: self.directResources,
          tapAction: self.resourceTapAction,
          menuAction: self.resourceMenuAction
        )
      }
    }
    .refreshable {
      await self.refreshAction()
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
  }
}
