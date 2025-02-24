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

import Display
import OSFeatures
import Resources
import SharedUIComponents

internal final class ResourcesListCreateMenuViewController: ViewController {

  private let navigation: DisplayNavigation

  private let context: ResourceFolder.ID?
  private let features: Features

  internal init(
    context: ResourceFolder.ID?,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.navigation = try features.instance()
  }
}

extension ResourcesListCreateMenuViewController {

  internal final func close() async {
    await self.navigation
      .dismissLegacySheet(ResourcesListCreateMenuView.self)
  }

  internal final func createResource() async throws {
    let resourceEditPreparation: ResourceEditPreparation = try self.features.instance()
    let metadataSettingsService: MetadataSettingsService = try self.features.instance()

    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(
      metadataSettingsService.typesSettings().defaultResourceTypeSlug,
      self.context,
      .none
    )
    await self.navigation
      .dismissLegacySheet(ResourcesListCreateMenuView.self)
    try await self.features
      .instance(of: NavigationToResourceEdit.self)
      .perform(
        context: .init(
          editingContext: editingContext
        )
      )
  }

  internal final func createFolder() async throws {
    await self.navigation
      .dismissLegacySheet(ResourcesListCreateMenuView.self)
    let editingFeatures: Features = try await self.features.instance(of: ResourceFolderEditPreparation.self)
      .prepareNew(context)
    try await self.navigation.push(
      ResourceFolderEditView.self,
      controller: editingFeatures.instance()
    )
  }
}
