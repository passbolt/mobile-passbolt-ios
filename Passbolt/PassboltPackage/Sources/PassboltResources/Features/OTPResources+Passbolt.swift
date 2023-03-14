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

    let diagnostics: OSDiagnostics = features.instance()
    let time: OSTime = features.instance()

    let sessionData: SessionData = try features.instance()
    //  MOB-1107 add new database operation
    //		let databaseListFetch: OTPResourcesListFetchDatabaseOperation = try features.instance()

    @_transparent
    @Sendable nonisolated func refreshIfNeeded() async throws {
      try await sessionData.refreshIfNeeded()
    }

    @Sendable nonisolated func filteredList(
      _ filter: OTPResourcesFilter
    ) async throws -> Array<OTPResourceListItemDSV> {
      #warning("[MOB-1107] TODO: add database and backend support")
      // MOCK - start
      try await Task.sleep(nanoseconds: ((NSEC_PER_MSEC * 100)..<(NSEC_PER_MSEC * 1000)).randomElement()!)
      return
        ([
          .init(
            id: "I65VU7K5ZQL7WB4E",
            name: "I65VU7K5ZQL7WB4E",
            url: .none
          ),
          .init(
            id: "OBQXG43CN5WHI===",
            name: "OBQXG43CN5WHI===",
            url: "https://passbolt.com/"
          ),
        ]
        + (0...100)
        .map { i in
          .init(
            id: "MZXW\(i)",
            name: "MZXW\(i)",
            url: .none
          )
        })
        .filter {
          if filter.text.isEmpty {
            return true
          }
          else {
            return $0.name
              .contains(filter.text)
          }
        }
      // MOCK - end
    }

    @Sendable nonisolated func secretFor(
      _ id: Resource.ID
    ) async throws -> OTPSecret {
      #warning("[MOB-1107] TODO: add database and backend support")
      // MOCK - start
      return .totp(
        sharedSecret: "\(id)",
        algorithm: .sha1,
        digits: 6,
        period: 30
      )
      // MOCK - end
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
