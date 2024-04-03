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
import Features
import Foundation
import Gopenpgp

public struct PGP {
  // The following functions accept private & public keys as PGP formatted strings
  // https://pkg.go.dev/github.com/ProtonMail/gopenpgp/v2#readme-documentation
  // Set time offset for PGP operations to compensate
  // difference between server and client time.
  // NOTE: It will keep the offset as long as the application is running
  // and apply it to all crypto operations thare are made through PGP.
  public var setTimeOffset: (Seconds) -> Void
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
  public var extractPublicKey:
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<ArmoredPGPPublicKey, Error>
  public var readCleartextMessage:
    (
      _ message: Data
    ) -> Result<String, Error>
  public var isPGPSignedClearMessage:
    (
      _ message: String
    ) -> Bool
}

extension PGP: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      setTimeOffset: unimplemented1(),
      encryptAndSign: unimplemented4(),
      decryptAndVerify: unimplemented4(),
      encrypt: unimplemented2(),
      decrypt: unimplemented3(),
      signMessage: unimplemented3(),
      verifyMessage: unimplemented3(),
      verifyPassphrase: unimplemented2(),
      verifyPublicKeyFingerprint: unimplemented2(),
      extractFingerprint: unimplemented1(),
      extractPublicKey: unimplemented2(),
      readCleartextMessage: unimplemented1(),
      isPGPSignedClearMessage: unimplemented1()
    )
  }
  #endif
}

extension PGP {

  internal static func gopenPGP() -> Self {

    func setTimeOffset(
      value: Seconds
    ) {
      Gopenpgp.CryptoSetTimeOffset(value.rawValue)
    }

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
        )?
        .getFingerprint()
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
        )?
        .getFingerprint()
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

    func extractPublicKey(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> Result<ArmoredPGPPublicKey, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      do {
        var error: NSError?

        guard
          let passphraseData: Data = passphrase.rawValue.data(using: .utf8),
          let publicKey: String = try Gopenpgp.CryptoNewKeyFromArmored(
            privateKey.rawValue,
            &error
          )?
          .unlock(passphraseData)
          .getArmoredPublicKey(&error)
        else {
          return .failure(
            PGPIssue.error(
              underlyingError:
                PGPFingerprintInvalid
                .error("Failed to extract public PGP key from a private key.")
                .recording(error as Any, for: "goError")
            )
          )
        }

        return .success(.init(rawValue: publicKey))
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

    /**
     * Reads and decodes a cleartext message from a PGP message.
     *
     * This function takes a PGP message in the form of a Data object, attempts to unarmor and decode it into a UTF-8 encoded string.
     *
     * @param {Data} message - The PGP message to be decoded.
     * @returns {Result<String, Error>} A Result object containing either the decoded message or an error specifying the failure reason.
     */
    func readCleartextMessage(
      message: Data
    ) -> Result<String, Error> {
      defer { Gopenpgp.HelperFreeOSMemory() }

      guard let decodedString: String = .init(data: message, encoding: .utf8),
            isPGPSignedClearMessage(decodedString) else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PGPClearTextMessageInvalid
              .error("Decoding failed or message is not PGP signed clear message.")
          )
        )
      }

      let pgpMessage = Gopenpgp.CryptoNewPGPMessage(message)

      var armorError: NSError?
      guard let armoredMessage = pgpMessage?.getArmored(&armorError) else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PGPClearTextMessageInvalid
              .error("Cannot extract armored message.")
          ))
      }

      var unarmorError: NSError?
      guard let decodedData = Gopenpgp.ArmorUnarmor(armoredMessage, &unarmorError),
            let decodedMessage: String = .init(data: decodedData, encoding: .utf8) else {
          return .failure(
            PGPIssue.error(
              underlyingError:
                PGPClearTextMessageInvalid
                .error("Cannot unarmor the message.")
            ))
      }

      return .success(decodedMessage)
    }

    /**
     * Check if clear message is a validate PGP Message
     * Used because during implementation we do not have GoPGPMessage function to perform it
     *
     * @param {String} message - The message to verify.
     * @returns {Bool} A boolean object.
     */
    func isPGPSignedClearMessage(_ message: String) -> Bool {
      // regex for PGP message
      let pgpMessageRegex: Regex = "[-]{5}BEGIN PGP SIGNED MESSAGE[-]{5}(.*?)[-]{5}BEGIN PGP SIGNATURE[-]{5}(.*?)[-]{5}END PGP SIGNATURE[-]{5}"
      //Remove string \n to avoid use case from different OS formatting during export
      let messageWithoutNewlines = message.replacingOccurrences(of: "\n", with: "")

      return messageWithoutNewlines.matches(regex: pgpMessageRegex)
    }

    return Self(
      setTimeOffset: setTimeOffset(value:),
      encryptAndSign: encryptAndSign(_:passphrase:privateKey:publicKey:),
      decryptAndVerify: decryptAndVerify(_:passphrase:privateKey:publicKey:),
      encrypt: encrypt(_:publicKey:),
      decrypt: decrypt(_:passphrase:privateKey:),
      signMessage: signMessage(_:passphrase:privateKey:),
      verifyMessage: verifyMessage(_:publicKey:verifyTime:),
      verifyPassphrase: verifyPassphrase(privateKey:passphrase:),
      verifyPublicKeyFingerprint: verifyPublicKeyFingerprint(_:fingerprint:),
      extractFingerprint: extractFingerprint(publicKey:),
      extractPublicKey: extractPublicKey(privateKey:passphrase:),
      readCleartextMessage: readCleartextMessage(message:),
      isPGPSignedClearMessage: isPGPSignedClearMessage(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePGP() {
    self.use(
      PGP.gopenPGP()
    )
  }
}
