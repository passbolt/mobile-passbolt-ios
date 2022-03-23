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
import Crypto
import Features

public struct FingerprintStorage {

  public var loadServerFingerprint: @StorageAccessActor (Account.LocalID) -> Result<Fingerprint?, Error>
  public var storeServerFingerprint: @StorageAccessActor (Account.LocalID, Fingerprint) -> Result<Void, Error>
}

extension FingerprintStorage: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> FingerprintStorage {

    let accountDataStore: AccountsDataStore = try await features.instance()

    @StorageAccessActor func loadServerFingerprint(accountID: Account.LocalID) -> Result<Fingerprint?, Error> {
      accountDataStore.loadServerFingerprint(accountID)
    }

    @StorageAccessActor func storeServerFingerprint(
      accountID: Account.LocalID,
      fingerprint: Fingerprint
    ) -> Result<Void, Error> {
      accountDataStore.storeServerFingerprint(accountID, fingerprint)
    }

    return Self(
      loadServerFingerprint: loadServerFingerprint(accountID:),
      storeServerFingerprint: storeServerFingerprint(accountID:fingerprint:)
    )
  }
}

#if DEBUG
extension FingerprintStorage {

  public static var placeholder: FingerprintStorage {
    Self(
      loadServerFingerprint: unimplemented("You have to provide mocks for used"),
      storeServerFingerprint: unimplemented("You have to provide mocks for used")
    )
  }
}
#endif
