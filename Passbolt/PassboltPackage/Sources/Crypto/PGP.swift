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

import Commons
import Foundation
import Gopenpgp

public struct PGP {
  // The following functions accept private & public keys as PGP formatted strings
  // https://pkg.go.dev/github.com/ProtonMail/gopenpgp/v2#readme-documentation

  // Encrypt and sign
  public var encryptAndSign:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError>
  // Decrypt and verify signature
  public var decryptAndVerify:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError>
  // Encrypt without signing
  public var encrypt:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError>
  // Decrypt without verifying signature
  public var decrypt:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheError>
  // Sign cleartext message
  public var signMessage:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheError>
  // Verify cleartext message
  public var verifyMessage:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey,
      _ verifyTime: Int64
    ) -> Result<String, TheError>
  // Verify if passhrase is correct
  public var verifyPassphrase:
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<Void, TheError>
}

extension PGP {

  public static func gopenPGP() -> Self {

    func encryptAndSign(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8) else {
        return .failure(.invalidPassphraseError())
      }

      var error: NSError?
      let result: String = Gopenpgp.HelperEncryptSignMessageArmored(
        publicKey.rawValue,
        privateKey.rawValue,
        passphraseData,
        input,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      if
        nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        ( // gopenpgp has multiple strings for the same error...
          errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains("gopenpgp: error in unlocking key")
        )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheError.pgpError(nsError)))
      } else {
        return .failure(.pgpError(nsError))
      }
    }

    func decryptAndVerify(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8) else {
        return .failure(.invalidPassphraseError())
      }

      var error: NSError?
      let result: String = Gopenpgp.HelperDecryptVerifyMessageArmored(
        publicKey.rawValue,
        privateKey.rawValue,
        passphraseData,
        input,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      if
        nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        ( // gopenpgp has multiple strings for the same error...
          errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains("gopenpgp: error in unlocking key")
        )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheError.pgpError(nsError)))
      } else {
        return .failure(.pgpError(nsError))
      }
    }

    func encrypt(
      _ input: String,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?
      let result: String = Gopenpgp.HelperEncryptMessageArmored(
        publicKey.rawValue,
        input,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      return .failure(.pgpError(nsError))
    }

    func decrypt(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8) else {
        return .failure(.invalidPassphraseError())
      }

      var error: NSError?
      let result: String = Gopenpgp.HelperDecryptMessageArmored(
        privateKey.rawValue,
        passphraseData,
        input,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      if
        nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        ( // gopenpgp has multiple strings for the same error...
          errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains("gopenpgp: error in unlocking key")
        )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheError.pgpError(nsError)))
      } else {
        return .failure(.pgpError(nsError))
      }
    }

    func signMessage(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8) else {
        return .failure(.invalidPassphraseError())
      }

      var error: NSError?
      let result: String = Gopenpgp.HelperSignCleartextMessageArmored(
        privateKey.rawValue,
        passphraseData,
        input,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      if
        nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        ( // gopenpgp has multiple strings for the same error...
          errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains("gopenpgp: error in unlocking key")
        )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheError.pgpError(nsError)))
      } else {
        return .failure(.pgpError(nsError))
      }
    }

    func verifyMessage(
      _ input: String,
      publicKey: ArmoredPGPPublicKey,
      verifyTime: Int64
    ) -> Result<String, TheError> {
      guard !input.isEmpty else {
        return .failure(.invalidInputDataError())
      }

      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?
      let result: String = Gopenpgp.HelperVerifyCleartextMessageArmored(
        publicKey.rawValue,
        input,
        verifyTime,
        &error
      )

      guard let nsError: NSError = error else {
        return .success(result)
      }

      return .failure(.pgpError(nsError))
    }

    func verifyPassphrase(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> Result<Void, TheError> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard
        let cryptoKey: CryptoKey = Gopenpgp.CryptoKey(fromArmored: privateKey.rawValue),
        let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(.invalidPassphraseError())
      }

      do {
        _ = try cryptoKey.unlock(passphraseData)
        return .success(())
      }
      catch {
        return .failure(.invalidPassphraseError())
      }
    }

    return Self(
      encryptAndSign: encryptAndSign(_:passphrase:privateKey:publicKey:),
      decryptAndVerify: decryptAndVerify(_:passphrase:privateKey:publicKey:),
      encrypt: encrypt(_:publicKey:),
      decrypt: decrypt(_:passphrase:privateKey:),
      signMessage: signMessage(_:passphrase:privateKey:),
      verifyMessage: verifyMessage(_:publicKey:verifyTime:),
      verifyPassphrase: verifyPassphrase(privateKey:passphrase:)
    )
  }
}

#if DEBUG
extension PGP {

  public static var placeholder: Self {
    Self(
      encryptAndSign: Commons.placeholder("You have to provide mocks for used methods"),
      decryptAndVerify: Commons.placeholder("You have to provide mocks for used methods"),
      encrypt: Commons.placeholder("You have to provide mocks for used methods"),
      decrypt: Commons.placeholder("You have to provide mocks for used methods"),
      signMessage: Commons.placeholder("You have to provide mocks for used methods"),
      verifyMessage: Commons.placeholder("You have to provide mocks for used methods"),
      verifyPassphrase: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
