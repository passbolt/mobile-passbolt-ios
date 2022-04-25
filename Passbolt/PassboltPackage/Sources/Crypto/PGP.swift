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
    ) -> Result<String, Error>
  // Decrypt and verify signature
  public var decryptAndVerify:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error>
  // Encrypt without signing
  public var encrypt:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error>
  // Decrypt without verifying signature
  public var decrypt:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error>
  // Sign cleartext message
  public var signMessage:
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error>
  // Verify cleartext message
  public var verifyMessage:
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey,
      _ verifyTime: Int64
    ) -> Result<String, Error>
  // Verify if passhrase is correct
  public var verifyPassphrase:
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<Void, Error>

  public var verifyPublicKeyFingerprint:
    (
      _ publicKey: ArmoredPGPPublicKey,
      _ fingerprint: Fingerprint
    ) -> Result<Bool, Error>

  public var extractFingerprint:
    (
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, Error>
}

extension PGP {

  public static func gopenPGP() -> Self {

    func encryptAndSign(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase data used for encryption with signature")
              .recording(passphrase, for: "passphrase")
          )
        )
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
        // gopenpgp has multiple strings for the same error...
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase used for encryption with signature")
              .recording(passphrase, for: "v")
              .recording(nsError, for: "goError")
          )
        )
      }
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              Unidentified
              .error(
                "Data encryption with signature failed",
                underlyingError: nsError
              )
              .recording(publicKey, for: "publicKey")
              .recording(privateKey, for: "privateKey")
              .recording(passphrase, for: "passphrase")
              .recording(input, for: "input")
          )
        )
      }
    }

    func decryptAndVerify(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase data used for decryption with verification")
              .recording(passphrase, for: "passphrase")
          )
        )
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
        // gopenpgp has multiple strings for the same error...
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error(
                "Invalid passphrase used for decryption with verification"
              )
              .recording(passphrase, for: "passphrase")
              .recording(nsError, for: "goError")
          )
        )
      }
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              Unidentified
              .error(
                "Data decryption with verification failed",
                underlyingError: nsError
              )
              .recording(publicKey, for: "publicKey")
              .recording(privateKey, for: "privateKey")
              .recording(passphrase, for: "passphrase")
              .recording(input, for: "input")
          )
        )
      }
    }

    func encrypt(
      _ input: String,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error> {
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

      return .failure(
        PGPIssue.error(
          underlyingError:
            Unidentified
            .error(
              "Data encryption failed",
              underlyingError: nsError
            )
            .recording(publicKey, for: "publicKey")
            .recording(input, for: "input")
        )
      )
    }

    func decrypt(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase data used for decryption")
              .recording(passphrase, for: "passphrase")
          )
        )
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
        // gopenpgp has multiple strings for the same error...
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase used for decryption")
              .recording(passphrase, for: "passphrase")
              .recording(nsError, for: "goError")
          )
        )
      }
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              Unidentified
              .error(
                "Data decryption failed",
                underlyingError: nsError
              )
              .recording(privateKey, for: "privateKey")
              .recording(passphrase, for: "passphrase")
              .recording(input, for: "input")
          )
        )
      }
    }

    func signMessage(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase data used for preparing signature")
              .recording(passphrase, for: "passphrase")
          )
        )
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
        // gopenpgp has multiple strings for the same error...
        let errorDescription: String = nsError.userInfo[NSLocalizedDescriptionKey] as? String,
        errorDescription.contains("gopenpgp: unable to unlock key")
          || errorDescription.contains(
            "gopenpgp: error in unlocking key"
          )
      {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase used for preparing signature")
              .recording(passphrase, for: "passphrase")
              .recording(nsError, for: "goError")
          )
        )
      }
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              Unidentified
              .error(
                "Data signing failed",
                underlyingError: nsError
              )
              .recording(privateKey, for: "privateKey")
              .recording(passphrase, for: "passphrase")
              .recording(input, for: "input")
          )
        )
      }
    }

    func verifyMessage(
      _ input: String,
      publicKey: ArmoredPGPPublicKey,
      verifyTime: Int64
    ) -> Result<String, Error> {
      guard !input.isEmpty else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              DataInvalid
              .error("Empty data for signature verification")
              .recording(input, for: "input")
          )
        )
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

      return .failure(
        PGPIssue.error(
          underlyingError:
            Unidentified
            .error(
              "Data signature verification failed",
              underlyingError: nsError
            )
            .recording(publicKey, for: "publicKey")
            .recording(verifyTime, for: "verifyTime")
            .recording(input, for: "input")
        )
      )
    }

    func verifyPassphrase(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> Result<Void, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard
        let cryptoKey: CryptoKey = Gopenpgp.CryptoKey(fromArmored: privateKey.rawValue),
        let passphraseData: Data = passphrase.rawValue.data(using: .utf8)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase data used for passphrase verification")
              .recording(passphrase, for: "passphrase")
          )
        )
      }

      do {
        _ = try cryptoKey.unlock(passphraseData)
        return .success(())
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PassphraseInvalid
              .error("Invalid passphrase")
              .recording(passphrase, for: "passphrase")
              .recording(error, for: "goError")
          )
        )
      }
    }

    func verifyPublicKeyFingerprint(
      _ publicKey: ArmoredPGPPublicKey,
      fingerprint: Fingerprint
    ) -> Result<Bool, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?

      guard
        let fingerprintFromKey: String = Gopenpgp.CryptoNewKeyFromArmored(
          publicKey.rawValue,
          &error
        )?.getFingerprint()
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PGPFingerprintInvalid
              .error("Failed to extract fingerptint from public PGP key")
              .recording(publicKey, for: "publicKey")
              .recording(error as Any, for: "goError")
          )
        )
      }

      return .success(fingerprintFromKey.uppercased() == fingerprint.rawValue.uppercased())
    }

    func extractFingerprint(
      publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      var error: NSError?

      guard
        let fingerprintFromKey: String = Gopenpgp.CryptoNewKeyFromArmored(
          publicKey.rawValue,
          &error
        )?.getFingerprint()
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PGPFingerprintInvalid
              .error("Failed to extract fingerptint from public PGP key")
              .recording(publicKey, for: "publicKey")
              .recording(error as Any, for: "goError")
          )
        )
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
