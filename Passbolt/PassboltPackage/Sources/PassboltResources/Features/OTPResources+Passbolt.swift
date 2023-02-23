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
      #warning("TODO: MOB-1107 add database support")
      // MOCK - start
      try await Task.sleep(nanoseconds: ((NSEC_PER_MSEC * 100)..<(NSEC_PER_MSEC * 1000)).randomElement()!)
      return
        ([
          .init(
            id: "Facebook",
            name: "Facebook",
            url: .none
          ),
          .init(
            id: "Google",
            name: "Google",
            url: "https://passbolt.com/"
          ),
        ]
        + (0...100)
        .map { i in
          .init(
            id: "MOCK_\(i)",
            name: "MOCK_\(i)",
            url: "https://passbolt.com/"
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

    @Sendable nonisolated func totpCodesFor(
      _ id: Resource.ID
    ) async throws -> AnyAsyncSequence<TOTPValue> {
      #warning("TODO: MOB-1107 add database support")
      // MOCK - start
      return
        time
        .timerSequence(1)
        .map {
          let timestamp: UInt64 = UInt64(time.timestamp().rawValue)
          return TOTPValue(
            otp: .init(
              rawValue: String(
                format: "1234%2d",
                arguments: [timestamp / 30 % 100]
              )
            ),
            timeLeft: Seconds(
              rawValue: UInt64(
                30 - timestamp % 30
              )
            ),
            validityPeriod: 30
          )
        }
        .asAnyAsyncSequence()
      // MOCK - end
    }

    return Self(
      updates: sessionData.updatesSequence,
      refreshIfNeeded: refreshIfNeeded,
      filteredList: filteredList(_:),
      totpCodesFor: totpCodesFor(_:)
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
