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

import Features

// MARK: - Interface

/// SessionCryptography feature allows to use
/// cryptography operations associated with current session.
public struct SessionCryptography {
  /// Decrypt message with current session if any.
  /// Optionally verify signature if public key was provided.
  /// Waits for session authorization if needed.
  /// Throws if there is no session.
  public var decryptMessage:
    @SessionActor (
      _ encryptedMessage: ArmoredPGPMessage,
      _ publicKey: ArmoredPGPPublicKey?
    ) async throws -> String
  /// Encrypt and sign message using provided public
  /// key with current session user signature.
  /// Waits for session authorization if needed.
  /// Throws if there is no session.
  public var encryptAndSignMessage:
    @SessionActor (
      _ plainMessage: String,
      _ publicKey: ArmoredPGPPublicKey
    ) async throws -> ArmoredPGPMessage
  
  public var decryptSessionKey:
    @SessionActor (
      _ message: ArmoredPGPMessage
    ) async throws -> SessionKey

  public init(
    decryptMessage: @escaping @SessionActor (
      _ encryptedMessage: ArmoredPGPMessage,
      _ publicKey: ArmoredPGPPublicKey?
    ) async throws -> String,
    encryptAndSignMessage: @escaping @SessionActor (
      _ plainMessage: String,
      _ publicKey: ArmoredPGPPublicKey
    ) async throws -> ArmoredPGPMessage,
    decryptSessionKey: @escaping @SessionActor (
      _ message: ArmoredPGPMessage
    ) async throws -> SessionKey
  ) {
    self.decryptMessage = decryptMessage
    self.encryptAndSignMessage = encryptAndSignMessage
    self.decryptSessionKey = decryptSessionKey
  }
}

extension SessionCryptography: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      decryptMessage: unimplemented2(),
      encryptAndSignMessage: unimplemented2(),
      decryptSessionKey: unimplemented1()
    )
  }
  #endif
}
