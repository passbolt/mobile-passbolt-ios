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
import NetworkOperations
import OSFeatures
import Resources
import SessionData

// MARK: - Implementation

extension OTPResources {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let sessionData: SessionData = try features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try features.instance()

    @_transparent
    @Sendable nonisolated func refreshIfNeeded() async throws {
      try await sessionData.refreshIfNeeded()
    }

    @Sendable nonisolated func filteredList(
      _ filter: OTPResourcesFilter
    ) async throws -> Array<ResourceListItemDSV> {
      try await resourcesListFetchDatabaseOperation(
        .init(
          sorting: .nameAlphabetically,
          text: filter.text,
          includedTypeSlugs: [.totp]
        )
      )
    }

    @Sendable nonisolated func secretFor(
      _ id: Resource.ID
    ) async throws -> TOTPSecret {
      let features: Features =
        await features.branchIfNeeded(
          scope: ResourceDetailsScope.self,
          context: id
        ) ?? features
      let resourceController: ResourceController = try await features.instance()
      let resourceSecret: JSON = try await resourceController.fetchSecretIfNeeded()

			// searching only for "totp" field, can't identify totp otherwise now
			guard let totpSecret: TOTPSecret = resourceSecret.totp.totpSecretValue
			else {
				throw
					InvalidResourceData
					.error(message: "Invalid or missing TOTP in secret")
			}

      return TOTPSecret(
				sharedSecret: totpSecret.sharedSecret,
				algorithm: totpSecret.algorithm,
				digits: totpSecret.digits,
				period: totpSecret.period
      )
    }

    return Self(
      updates: sessionData.updatesSequence,
      refreshIfNeeded: refreshIfNeeded,
      filteredList: filteredList(_:),
      secretFor: secretFor(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltOTPResources() {
    self.use(
      .disposable(
        OTPResources.self,
        load: OTPResources.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
