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
    ) -> Result<String, TheErrorLegacy>
  // Decrypt and verify signature
  public var decryptAndVerify:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheErrorLegacy>
  // Encrypt without signing
  public var encrypt:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheErrorLegacy>
  // Decrypt without verifying signature
  public var decrypt:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheErrorLegacy>
  // Sign cleartext message
  public var signMessage:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheErrorLegacy>
  // Verify cleartext message
  public var verifyMessage:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey,
      _ verifyTime: Int64
    ) -> Result<String, TheErrorLegacy>
  // Verify if passhrase is correct
  public var verifyPassphrase:
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<Void, TheErrorLegacy>

  public var verifyPublicKeyFingerprint:
    (
      _ publicKey: ArmoredPGPPublicKey,
      _ fingerprint: Fingerprint
    ) -> Result<Bool, TheErrorLegacy>

  public var extractFingerprint:
    (
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, TheErrorLegacy>
}

extension PGP {

  public static func gopenPGP() -> Self {

    func encryptAndSign(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheErrorLegacy> {
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

      if nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,  // gopenpgp has multiple strings for the same error...
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheErrorLegacy.pgpError(nsError)))
      }
      else {
        return .failure(.pgpError(nsError))
      }
    }

    func decryptAndVerify(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheErrorLegacy> {
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

      if nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,  // gopenpgp has multiple strings for the same error...
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheErrorLegacy.pgpError(nsError)))
      }
      else {
        return .failure(.pgpError(nsError))
      }
    }

    func encrypt(
      _ input: String,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, TheErrorLegacy> {
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
    ) -> Result<String, TheErrorLegacy> {
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

      if nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,  // gopenpgp has multiple strings for the same error...
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheErrorLegacy.pgpError(nsError)))
      }
      else {
        return .failure(.pgpError(nsError))
      }
    }

    func signMessage(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, TheErrorLegacy> {
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

      if nsError.domain == "go",
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,  // gopenpgp has multiple strings for the same error...
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(.invalidPassphraseError(underlyingError: TheErrorLegacy.pgpError(nsError)))
      }
      else {
        return .failure(.pgpError(nsError))
      }
    }

    func verifyMessage(
      _ input: String,
      publicKey: ArmoredPGPPublicKey,
      verifyTime: Int64
    ) -> Result<String, TheErrorLegacy> {
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
    ) -> Result<Void, TheErrorLegacy> {
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

    func verifyPublicKeyFingerprint(
      _ publicKey: ArmoredPGPPublicKey,
      fingerprint: Fingerprint
    ) -> Result<Bool, TheErrorLegacy> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?

      guard
        let fingerprintFromKey: String = Gopenpgp.CryptoNewKeyFromArmored(
          publicKey.rawValue,
          &error
        )?.getFingerprint()
      else {
        return .failure(.failedToGetPGPFingerprint(underlyingError: error))
      }

      return .success(fingerprintFromKey.uppercased() == fingerprint.rawValue.uppercased())
    }

    func extractFingerprint(
      publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, TheErrorLegacy> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?

      guard
        let fingerprintFromKey: String = Gopenpgp.CryptoNewKeyFromArmored(
          publicKey.rawValue,
          &error
        )?.getFingerprint()
      else {
        return .failure(.failedToGetPGPFingerprint(underlyingError: error))
      }

      return .success(.init(rawValue: fingerprintFromKey.uppercased()))
    }

    return Self(
      encryptAndSign: encryptAndSign(_:passphrase:privateKey:publicKey:),
      decryptAndVerify: decryptAndVerify(_:passphrase:privateKey:publicKey:),
      encrypt: encrypt(_:publicKey:),
      decrypt: decrypt(_:passphrase:privateKey:),
      signMessage: signMessage(_:passphrase:privateKey:),
      verifyMessage: verifyMessage(_:publicKey:verifyTime:),
      verifyPassphrase: verifyPassphrase(privateKey:passphrase:),
      verifyPublicKeyFingerprint: verifyPublicKeyFingerprint(_:fingerprint:),
      extractFingerprint: extractFingerprint(publicKey:)
    )
  }
}

#if DEBUG
extension PGP {

  public static var placeholder: Self {
    Self(
      encryptAndSign: unimplemented("You have to provide mocks for used methods"),
      decryptAndVerify: unimplemented("You have to provide mocks for used methods"),
      encrypt: unimplemented("You have to provide mocks for used methods"),
      decrypt: unimplemented("You have to provide mocks for used methods"),
      signMessage: unimplemented("You have to provide mocks for used methods"),
      verifyMessage: unimplemented("You have to provide mocks for used methods"),
      verifyPassphrase: unimplemented("You have to provide mocks for used methods"),
      verifyPublicKeyFingerprint: unimplemented("You have to provide mocks for used methods"),
      extractFingerprint: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
