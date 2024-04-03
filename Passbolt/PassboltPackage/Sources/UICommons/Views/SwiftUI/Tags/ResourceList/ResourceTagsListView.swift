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

public struct ResourceTagsListView: View {

  private let tags: Array<ResourceTagListItemDSV>
  private let contentEmpty: Bool
  private let refreshAction: () async -> Void
  private let createAction: (() async throws -> Void)?
  private let tagTapAction: (ResourceTag.ID) async throws -> Void

  public init(
    tags: Array<ResourceTagListItemDSV>,
    refreshAction: @escaping () async -> Void,
    createAction: (() async throws -> Void)?,
    tagTapAction: @escaping (ResourceTag.ID) async throws -> Void
  ) {
    self.tags = tags
    self.contentEmpty = tags.isEmpty
    self.refreshAction = refreshAction
    self.createAction = createAction
    self.tagTapAction = tagTapAction
  }

  public var body: some View {
    List {
      if let createAction: () async throws -> Void = self.createAction {
        ResourceListAddView(action: createAction)
      }  // else no create row

      if self.contentEmpty {
        // empty
        EmptyListView()
      }
      else {
        ResourceTagsListSectionView(
          tags: self.tags,
          tapAction: self.tagTapAction
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
