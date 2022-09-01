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

public struct ResourcesListView: View {

  private let suggestedResources: Array<ResourceListItemDSV>?
  private let resources: Array<ResourceListItemDSV>
  private let contentEmpty: Bool
  private let refreshAction: () async -> Void
  private let createAction: (() -> Void)?
  private let resourceTapAction: (Resource.ID) -> Void
  private let resourceMenuAction: ((Resource.ID) -> Void)?

  public init(
    suggestedResources: Array<ResourceListItemDSV>?,
    resources: Array<ResourceListItemDSV>,
    refreshAction: @escaping () async -> Void,
    createAction: (() -> Void)?,
    resourceTapAction: @escaping (Resource.ID) -> Void,
    resourceMenuAction: ((Resource.ID) -> Void)?
  ) {
    self.suggestedResources = suggestedResources
    self.resources = resources
    self.contentEmpty =
      suggestedResources?.isEmpty ?? true
      && resources.isEmpty
    self.refreshAction = refreshAction
    self.createAction = createAction
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
      else if let suggestedResources: Array<ResourceListItemDSV> = self.suggestedResources {
        ResourcesListSectionView(
          title: .localized("autofill.extension.resource.list.section.suggested.title"),
          resources: suggestedResources,
          tapAction: self.resourceTapAction,
          menuAction: self.resourceMenuAction
        )

        ResourcesListSectionView(
          title: .localized("autofill.extension.resource.list.section.all.title"),
          resources: self.resources,
          tapAction: self.resourceTapAction,
          menuAction: self.resourceMenuAction
        )
      }
      else {
        ResourcesListSectionView(
          resources: self.resources,
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
