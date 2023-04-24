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

import Accounts
import Crypto
import Session

// MARK: - Implementation

extension SessionCryptography {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let accountsDataStore: AccountsDataStore = try features.instance()
    let session: Session = try features.instance()
    let sessionStateEnsurance: SessionStateEnsurance = try features.instance()
    let pgp: PGP = features.instance()

    @SessionActor func decryptMessage(
      _ encryptedMessage: ArmoredPGPMessage,
      _ publicKey: ArmoredPGPPublicKey?
    ) async throws -> String {
      let account: Account = try await session.currentAccount()

      let passphrase: Passphrase = try await sessionStateEnsurance.passphrase(account)

      let privateKey: ArmoredPGPPrivateKey = try accountsDataStore.loadAccountPrivateKey(account.localID)

      if let publicKey: ArmoredPGPPublicKey = publicKey {
        return
          try pgp.decryptAndVerify(
            encryptedMessage.rawValue,
            passphrase,
            privateKey,
            publicKey
          )
          .get()
      }
      else {
        return
          try pgp.decrypt(
            encryptedMessage.rawValue,
            passphrase,
            privateKey
          )
          .get()
      }
    }

    @SessionActor func encryptAndSignMessage(
      _ plainMessage: String,
      _ publicKey: ArmoredPGPPublicKey
    ) async throws -> ArmoredPGPMessage {
      let account: Account = try await session.currentAccount()

      let passphrase: Passphrase = try await sessionStateEnsurance.passphrase(account)

      let privateKey: ArmoredPGPPrivateKey = try accountsDataStore.loadAccountPrivateKey(account.localID)

      return
        try pgp.encryptAndSign(
          plainMessage,
          passphrase,
          privateKey,
          publicKey
        )
        .map(ArmoredPGPMessage.init(rawValue:))
        .get()
    }

    return Self(
      decryptMessage: decryptMessage(_:_:),
      encryptAndSignMessage: encryptAndSignMessage(_:_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionCryptography() {
    self.use(
      .lazyLoaded(
        SessionCryptography.self,
        load: SessionCryptography
          .load(features:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
