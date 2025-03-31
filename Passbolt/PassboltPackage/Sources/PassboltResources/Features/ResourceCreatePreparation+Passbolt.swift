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

import DatabaseOperations
import FeatureScopes
import Resources

extension ResourceCreatePreparation {

  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> Self {
    let resourceTypesDatabaseFetchOperation: ResourceTypesFetchDatabaseOperation = try features.instance()
    let metadataSettings: MetadataSettingsService = try features.instance()

    /// Prepares types for password and TOTP resources based on the metadata settings and types available in the database.
    @Sendable
    func prepareAvailableTypes() async throws -> ResourceCreatingContext {
      let allResourceTypes: Array<ResourceType> = try await resourceTypesDatabaseFetchOperation.execute(())
      let typesSettings: MetadataTypesSettings = metadataSettings.typesSettings()
      let areV5ResourceTypesEnabled: Bool = typesSettings.defaultResourceTypes == .v5
      let passwordSlug: ResourceSpecification.Slug = typesSettings.defaultResourceTypeSlug
      let totpSlug: ResourceSpecification.Slug = areV5ResourceTypesEnabled ? .v5StandaloneTOTP : .totp

      let passwordType: ResourceType? = allResourceTypes.first { $0.specification.slug == passwordSlug }
      let totpType: ResourceType? = allResourceTypes.first { $0.specification.slug == totpSlug }

      return .init(
        availableTypes: [
          passwordType,
          totpType,
        ]
        .compactMap { $0 }
      )
    }

    return .init(
      prepare: prepareAvailableTypes
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceCreatePreparation() {
    self.use(
      .disposable(
        ResourceCreatePreparation.self,
        load: ResourceCreatePreparation.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
