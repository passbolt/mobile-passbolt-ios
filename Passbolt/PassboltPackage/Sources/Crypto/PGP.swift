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
@preconcurrency import Gopenpgp

// Clock-skew tolerance (seconds) added to the verification time. gopenpgp rejects a signature
// created even one second after the verify time, and whole-second truncation plus imprecise
// client/server sync can push the verify time just below a fresh signature's creation time.
// Safe because Passbolt signatures have no lifetime, so this only loosens the future boundary.
private let verificationTimeTolerance: Int64 = 5

public struct PGP: Sendable {
  // The following functions accept private & public keys as PGP formatted strings
  // https://pkg.go.dev/github.com/ProtonMail/gopenpgp/v2#readme-documentation
  // Set time offset for PGP operations to compensate
  // difference between server and client time.
  // NOTE: It will keep the offset as long as the application is running
  // and apply it to all crypto operations thare are made through PGP.
  public var setTimeOffset: @Sendable (Seconds) -> Void
  // Encrypt and sign
  public var encryptAndSign:
    @Sendable
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error>
  // Decrypt and verify signature
  public var decryptAndVerify:
    @Sendable
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<VerifiedMessage, Error>
  // Encrypt without signing
  public var encrypt:
    @Sendable
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error>
  // Decrypt without verifying signature
  public var decrypt:
    @Sendable
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error>
  // Decrypt with session key
  public var decryptWithSessionKey:
    @Sendable
    (
      _ message: String,
      _ sessionKey: SessionKey
    ) throws -> String?
  // Sign cleartext message
  public var signMessage:
    @Sendable
    (
      _ input: String,
      _ passphrase: Passphrase,
      _ privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error>
  // Verify cleartext message
  public var verifyMessage:
    @Sendable
    (
      _ input: String,
      _ publicKey: ArmoredPGPPublicKey,
      _ verifyTime: Int64
    ) -> Result<String, Error>
  // Verify if passhrase is correct
  public var verifyPassphrase:
    @Sendable
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<Void, Error>

  public var verifyPublicKeyFingerprint:
    @Sendable
    (
      _ publicKey: ArmoredPGPPublicKey,
      _ fingerprint: Fingerprint
    ) -> Result<Bool, Error>

  public var extractFingerprint:
    @Sendable
    (
      _ publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, Error>
  public var extractPublicKey:
    @Sendable
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> Result<ArmoredPGPPublicKey, Error>

  public var readCleartextMessage:
    @Sendable
    (
      _ message: Data
    ) -> Result<String, Error>
  public var isPGPSignedClearMessage:
    @Sendable
    (
      _ message: String
    ) -> Bool

  public var configuredDecryptor:
    @Sendable
    (
      _ privateKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) throws -> ConfiguredDecryptor

  public var forceFreeMemory: @Sendable () -> Void
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
      decryptWithSessionKey: unimplemented2(),
      signMessage: unimplemented3(),
      verifyMessage: unimplemented3(),
      verifyPassphrase: unimplemented2(),
      verifyPublicKeyFingerprint: unimplemented2(),
      extractFingerprint: unimplemented1(),
      extractPublicKey: unimplemented2(),
      readCleartextMessage: unimplemented1(),
      isPGPSignedClearMessage: unimplemented1(),
      configuredDecryptor: unimplemented2(),
      forceFreeMemory: unimplemented0()
    )
  }
  #endif
}

extension PGP {

  internal static func gopenPGP() -> Self {

    let timeOffset: CriticalState<Int64> = .init(0)
    @Sendable func setTimeOffset(
      value: Seconds
    ) {
      timeOffset.set(Int64(value.rawValue))
    }

    @Sendable func now() -> Int64 {
      Int64(Date.now.timeIntervalSince1970)
    }

    // Time used to verify signatures (never to create them): offset + clock-skew tolerance.
    @Sendable func verifyTime() -> Int64 {
      now() + timeOffset.get() + verificationTimeTolerance
    }

    @Sendable func createUnlockedPrivateKey(
      fromArmored privateKey: ArmoredPGPPrivateKey,
      withPassphrase passphrase: Passphrase
    ) throws -> CryptoKey {
      guard
        let key: CryptoKey = CryptoKey(fromArmored: privateKey.rawValue)
      else {
        throw PGPKeyRingPreparationFailed.error("Cannot create CryptoKey from armored key")
      }

      do {
        let passphraseData: Data? = passphrase.rawValue.data(using: .utf8)
        return try key.unlock(passphraseData)
      }
      catch {
        throw
          PassphraseInvalid
          .error("Invalid passphrase data used for encryption with signature")
          .recording(passphrase, for: "passphrase")
      }
    }

    @Sendable func createPublicKey(fromArmored publicKey: ArmoredPGPPublicKey) throws -> CryptoKey {
      if let key: CryptoKey = CryptoKey(fromArmored: publicKey.rawValue) {
        return key
      }
      throw PGPIssue.error(
        underlyingError: PGPGenericIssue.error("Cannot create CryptoKey from armored key")
      )
    }

    @Sendable func encryptAndSign(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let key: CryptoKey = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)
        let publicKey: CryptoKey = try createPublicKey(fromArmored: publicKey)
        let encryptor: CryptoPGPEncryptionProtocol = try CryptoPGPHandle.encryptor(
          with: {
            $0.signing(key)?
              .recipient(publicKey)
          }
        )

        let result: CryptoPGPMessage = try encryptor.encrypt(Data(input.utf8))
        let armoredData = try result.armorBytes()
        encryptor.clearPrivateParams()
        return .success(String(decoding: armoredData, as: UTF8.self))
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func decryptAndVerify(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<VerifiedMessage, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let key: CryptoKey = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)
        let verificationKey: CryptoKey = try createPublicKey(fromArmored: publicKey)
        let expectedFingerprint: String = verificationKey.getFingerprint()
        let decryptor: CryptoPGPDecryptionProtocol = try CryptoPGPHandle.decryptor(
          with: {
            $0.decryptionKey(key)?
              .verificationKey(verificationKey)?
              .verifyTime(verifyTime())
          })
        defer { decryptor.clearPrivateParams() }
        let inputData: Data = Data(input.utf8)
        let result: CryptoVerifiedDataResult = try decryptor.decrypt(inputData, encoding: PGPEncoding.auto.rawValue)
        // `signatureError` only catches tampered/expired/invalid signatures, not signers outside the
        // verification set; `decrypt` may also verify against the decryption key.
        try result.signatureError()
        // Confirm the signer is the supplied verification key. Match the verified key's primary
        // fingerprint so signatures made by its signing subkey (different issuer fingerprint) pass.
        guard
          let signingKey: CryptoKey = result.signedByKey(),
          signingKey.getFingerprint().caseInsensitiveCompare(expectedFingerprint) == .orderedSame
        else {
          throw PGPIssue.error(
            underlyingError: PGPGenericIssue.error("Signature was not created by the expected key")
          )
        }
        guard
          let data: Data = result.bytes(),
          let rawFingerprint: String = result.signedByFingerprint()?.bytesToHexString()
        else {
          throw PGPIssue.error(
            underlyingError: PGPGenericIssue.error("Cannot decode decrypted data")
          )
        }
        let signatureData: Data = try result.signature()
        let signature: Signature = .init(
          signature: String(decoding: signatureData, as: UTF8.self),
          createdAt: Date(timeIntervalSince1970: .init(result.signatureCreationTime())),
          fingerprint: .init(rawValue: rawFingerprint),
          keyID: result.signedByKeyIdHex()
        )
        let verifiedMessage: VerifiedMessage = .init(
          content: String(decoding: data, as: UTF8.self),
          signature: signature
        )
        return .success(verifiedMessage)
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func encrypt(
      _ input: String,
      publicKey: ArmoredPGPPublicKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let timeOffset: Int64 = timeOffset.get()
        let publicKey: CryptoKey = try createPublicKey(fromArmored: publicKey)
        let encryptor: CryptoPGPEncryptionProtocol = try CryptoPGPHandle.encryptor(
          with: {
            $0.recipient(publicKey)?
              .encryptionTime(now() + timeOffset)?
              .signTime(now() + timeOffset)
          })
        defer { encryptor.clearPrivateParams() }
        let result: CryptoPGPMessage = try encryptor.encrypt(Data(input.utf8))
        let armoredData = try result.armorBytes()
        return .success(String(decoding: armoredData, as: UTF8.self))
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError:
              Unidentified
              .error(
                "Data encryption failed",
                underlyingError: error.asTheError()
              )
              .recording(publicKey, for: "publicKey")
              .recording(input, for: "input")
          )
        )
      }
    }

    @Sendable func decrypt(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let key = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)

        guard let inputData: Data = input.data(using: .utf8) else {
          throw PGPIssue.error(
            underlyingError: PGPGenericIssue.error("Cannot create Data from input string")
          )
        }

        let decryptor: CryptoPGPDecryptionProtocol = try CryptoPGPHandle.decryptor(
          with: {
            $0.decryptionKey(key)?
              .verifyTime(verifyTime())
          })
        defer { decryptor.clearPrivateParams() }
        let result: CryptoVerifiedDataResult = try decryptor.decrypt(inputData, encoding: PGPEncoding.auto.rawValue)

        if let decryptedData: Data = result.bytes(),
          let decryptedString: String = String(data: decryptedData, encoding: .utf8)
        {
          return .success(decryptedString)
        }
        else {
          throw PGPGenericIssue.error("Cannot decode decrypted data")
        }
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError:
              error.asTheError()
          )
        )
      }
    }

    @Sendable func signMessage(
      _ input: String,
      passphrase: Passphrase,
      privateKey: ArmoredPGPPrivateKey
    ) -> Result<String, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let key: CryptoKey = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)
        let signer: CryptoPGPSignProtocol = try CryptoPGPHandle.signer(
          with: {
            $0.signing(key)?
              .signTime(now() + timeOffset.get())
          })
        defer { signer.clearPrivateParams() }
        let armoredData: Data = try signer.signCleartext(Data(input.utf8))
        return .success(String(decoding: armoredData, as: UTF8.self))
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func verifyMessage(
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

      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let verificationKey: CryptoKey = try createPublicKey(fromArmored: publicKey)
        let expectedFingerprint: String = verificationKey.getFingerprint()
        // verifyTime == 0 is gopenpgp's sentinel for "skip the time check"; adding the tolerance
        // would turn it into a real timestamp (5s after the epoch) and reject every genuine signature.
        let effectiveVerifyTime: Int64 = verifyTime == 0 ? 0 : verifyTime + verificationTimeTolerance
        let verifier: CryptoPGPVerifyProtocol = try CryptoPGPHandle.verifier(
          with: {
            $0.verificationKey(verificationKey)?
              .verifyTime(effectiveVerifyTime)
          })

        let inputData: Data = Data(input.utf8)
        let result: CryptoVerifyCleartextResult = try verifier.verifyCleartext(inputData)
        // `signatureError` does not reject signers outside the verification set.
        try result.signatureError()
        // Confirm the signer is the supplied verification key. Match the verified key's primary
        // fingerprint so signatures made by its signing subkey (different issuer fingerprint) pass.
        guard
          let signingKey: CryptoKey = result.signedByKey(),
          signingKey.getFingerprint().caseInsensitiveCompare(expectedFingerprint) == .orderedSame
        else {
          throw PGPIssue.error(
            underlyingError: PGPGenericIssue.error("Signature was not created by the expected key")
          )
        }
        guard let data: Data = result.cleartext()
        else {
          throw PGPIssue.error(
            underlyingError: PGPGenericIssue.error("Cannot decode verified data")
          )
        }
        return .success(String(decoding: data, as: UTF8.self))
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func verifyPassphrase(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> Result<Void, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        _ = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)
        return .success(())
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func verifyPublicKeyFingerprint(
      _ publicKey: ArmoredPGPPublicKey,
      fingerprint: Fingerprint
    ) -> Result<Bool, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      do {
        let extractedFingerprint: Fingerprint = try extractFingerprint(publicKey: publicKey)
        return .success(extractedFingerprint.rawValue.uppercased() == fingerprint.rawValue.uppercased())
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func extractFingerprint(
      publicKey: ArmoredPGPPublicKey
    ) throws -> Fingerprint {
      defer { Gopenpgp.MobileFreeOSMemory() }
      do {
        let publicKey: CryptoKey = try createPublicKey(fromArmored: publicKey)
        return .init(rawValue: publicKey.getFingerprint().uppercased())
      }
      catch {
        throw
          PGPFingerprintInvalid
          .error("Failed to extract fingerptint from public PGP key")
          .recording(publicKey, for: "publicKey")
          .recording(String(describing: error), for: "goError")
      }
    }

    @Sendable func extractFingerprint(
      publicKey: ArmoredPGPPublicKey
    ) -> Result<Fingerprint, Error> {
      do {
        let fingerprint: Fingerprint = try extractFingerprint(publicKey: publicKey)
        return .success(fingerprint)
      }
      catch {
        return .failure(
          PGPIssue.error(
            underlyingError: error.asTheError()
          )
        )
      }
    }

    @Sendable func extractPublicKey(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> Result<ArmoredPGPPublicKey, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

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
                .recording(String(describing: error), for: "goError")
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

    /// Reads and decodes a cleartext message from a PGP message.
    ///
    /// This function takes a PGP message in the form of a Data object, attempts to unarmor and decode it into a UTF-8 encoded string.
    ///
    /// - Parameter message: The PGP message to be decoded.
    /// - Returns: A Result object containing either the decoded message or an error specifying the failure reason.
    @Sendable func readCleartextMessage(
      message: Data
    ) -> Result<String, Error> {
      defer { Gopenpgp.MobileFreeOSMemory() }

      guard let decodedString: String = .init(data: message, encoding: .utf8),
        isPGPSignedClearMessage(decodedString)
      else {
        return .failure(
          PGPIssue.error(
            underlyingError:
              PGPClearTextMessageInvalid
              .error("Decoding failed or message is not PGP signed clear message.")
          )
        )
      }
      return .success(decodedString)
    }

    /// Check if clear message is a validate PGP Message
    /// Used because during implementation we do not have GoPGPMessage function to perform it
    ///
    /// - Parameter message: The message to verify.
    /// - Returns: A boolean object.
    @Sendable func isPGPSignedClearMessage(_ message: String) -> Bool {
      // regex for PGP message
      // swift-format-ignore
      let pgpMessageRegex: Regex = "[-]{5}BEGIN PGP SIGNED MESSAGE[-]{5}(.*?)[-]{5}BEGIN PGP SIGNATURE[-]{5}(.*?)[-]{5}END PGP SIGNATURE[-]{5}"
      //Remove string \n to avoid use case from different OS formatting during export
      let messageWithoutNewlines = message.replacingOccurrences(of: "\n", with: "")

      return messageWithoutNewlines.matches(regex: pgpMessageRegex)
    }

    /// Decrypts a message using a session key.
    /// - Parameters:
    /// - message: The message to decrypt, as a string.
    /// - sessionKey: The session key used for decryption.
    /// - Returns: The decrypted message as a string, or nil if decryption fails.
    /// - Throws: An error if the message cannot be converted to Data or if decryption fails.
    /// - Note: Remember to call `forceFreeMemory()` after using this function to free up memory used by the PGP library.
    @Sendable func decryptWithSessionKey(message: String, sessionKey: SessionKey) throws -> String? {
      guard let message: Data = message.data(using: .utf8) else {
        throw PGPIssue.error(
          underlyingError:
            PGPClearTextMessageInvalid
            .error("Cannot create Data from message string")
        )
      }
      let sessionKeyData: Data = .init(hexString: sessionKey.rawValue)

      let sessionKey = CryptoNewSessionKeyFromToken(sessionKeyData, ConstantsAES256)

      let decryptor: CryptoPGPDecryptionProtocol = try CryptoPGPHandle.decryptor(
        with: {
          $0.sessionKey(sessionKey)?
            .verifyTime(verifyTime())
        })
      let result = try decryptor.decrypt(message, encoding: PGPEncoding.auto.rawValue)
      if let decryptedData: Data = result.bytes(),
        let decryptedString: String = String(data: decryptedData, encoding: .utf8)
      {
        return decryptedString
      }
      return nil

    }

    @Sendable func configuredDecryptor(
      privateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) throws -> ConfiguredDecryptor {
      let key: CryptoKey = try createUnlockedPrivateKey(fromArmored: privateKey, withPassphrase: passphrase)
      let decryptor: CryptoPGPDecryptionProtocol = try CryptoPGPHandle.decryptor(
        with: {
          $0.decryptionKey(key)?
            .verifyTime(verifyTime())
          return $0.retrieveSessionKey()
        })

      return .init(
        decrypt: { (input: Data) -> (data: Data?, sessionKey: SessionKey?) in
          let result: CryptoVerifiedDataResult = try decryptor.decrypt(input, encoding: PGPEncoding.auto.rawValue)
          var sessionKey: SessionKey? = nil
          if let sessionKeyResult: CryptoSessionKey = result.sessionKey(),
            var sessionKeyString: String = sessionKeyResult.key?.bytesToHexString()
          {
            var cipherValue: Int8 = .min
            try sessionKeyResult.getCipherFuncInt(&cipherValue)
            if cipherValue != .min {
              sessionKeyString = "\(cipherValue):\(sessionKeyString)"
            }
            sessionKey = .init(rawValue: sessionKeyString)
          }
          return (data: result.bytes(), sessionKey: sessionKey)
        },
        deinitialize: {
          decryptor.clearPrivateParams()
        }
      )
    }

    return Self(
      setTimeOffset: setTimeOffset(value:),
      encryptAndSign: encryptAndSign(_:passphrase:privateKey:publicKey:),
      decryptAndVerify: decryptAndVerify(_:passphrase:privateKey:publicKey:),
      encrypt: encrypt(_:publicKey:),
      decrypt: decrypt(_:passphrase:privateKey:),
      decryptWithSessionKey: decryptWithSessionKey(message:sessionKey:),
      signMessage: signMessage(_:passphrase:privateKey:),
      verifyMessage: verifyMessage(_:publicKey:verifyTime:),
      verifyPassphrase: verifyPassphrase(privateKey:passphrase:),
      verifyPublicKeyFingerprint: verifyPublicKeyFingerprint(_:fingerprint:),
      extractFingerprint: extractFingerprint(publicKey:),
      extractPublicKey: extractPublicKey(privateKey:passphrase:),
      readCleartextMessage: readCleartextMessage(message:),
      isPGPSignedClearMessage: isPGPSignedClearMessage(_:),
      configuredDecryptor: configuredDecryptor(privateKey:passphrase:),
      forceFreeMemory: { Gopenpgp.MobileFreeOSMemory() }
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

struct PGPGenericIssue: TheError {

  var context: DiagnosticsContext
  var displayableMessage: DisplayableString

  public static func error(
    _ message: StaticString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          message,
          file: file,
          line: line
        )
      ),
      displayableMessage: .localized(key: "error.crypto.error.generic")
    )
  }
}

// Mapping of gopenpgp encoding
private enum PGPEncoding: Int8 {

  case armor = 0
  case bytes = 1
  case auto = 2
}

extension CryptoPGPHandle {

  fileprivate static func encryptor(
    with optionsBuilder: (CryptoEncryptionHandleBuilder) -> CryptoEncryptionHandleBuilder?
  ) throws -> CryptoPGPEncryptionProtocol {
    guard
      let pgpHandle: CryptoPGPHandle = CryptoPGPWithProfile(ProfileDefault()),
      let builder: CryptoEncryptionHandleBuilder = pgpHandle.encryption(),
      let configuredBuilder: CryptoEncryptionHandleBuilder = optionsBuilder(builder)
    else {
      throw PGPGenericIssue.error("Cannot initialize PGP")
    }

    return try configuredBuilder.new()
  }

  fileprivate static func decryptor(
    with optionsBuilder: (CryptoDecryptionHandleBuilder) -> CryptoDecryptionHandleBuilder?
  ) throws -> CryptoPGPDecryptionProtocol {
    guard
      let pgpHandle: CryptoPGPHandle = CryptoPGPWithProfile(ProfileDefault()),
      let builder: CryptoDecryptionHandleBuilder = pgpHandle.decryption(),
      let configuredBuilder: CryptoDecryptionHandleBuilder = optionsBuilder(builder)
    else {
      throw PGPGenericIssue.error("Cannot initialize PGP")
    }
    return try configuredBuilder.new()
  }

  fileprivate static func signer(
    with optionsBuilder: (CryptoSignHandleBuilder) -> CryptoSignHandleBuilder?
  ) throws -> CryptoPGPSignProtocol {
    guard
      let pgpHandle: CryptoPGPHandle = CryptoPGPWithProfile(ProfileDefault()),
      let builder: CryptoSignHandleBuilder = pgpHandle.sign(),
      let configuredBuilder: CryptoSignHandleBuilder = optionsBuilder(builder)
    else {
      throw PGPGenericIssue.error("Cannot initialize PGP")
    }

    return try configuredBuilder.new()
  }

  fileprivate static func verifier(
    with optionsBuilder: (CryptoVerifyHandleBuilder) -> CryptoVerifyHandleBuilder?
  ) throws -> CryptoPGPVerifyProtocol {
    guard
      let pgpHandle: CryptoPGPHandle = CryptoPGPWithProfile(ProfileDefault()),
      let builder: CryptoVerifyHandleBuilder = pgpHandle.verify(),
      let configuredBuilder: CryptoVerifyHandleBuilder = optionsBuilder(builder)
    else {
      throw PGPGenericIssue.error("Cannot initialize PGP")
    }

    return try configuredBuilder.new()
  }

}

extension PGP {

  public struct VerifiedMessage: Sendable {
    public let content: String
    public let signature: Signature

    public init(
      content: String,
      signature: PGP.Signature
    ) {
      self.content = content
      self.signature = signature
    }
  }

  public struct Signature: Sendable {
    public let signature: String
    public let createdAt: Date
    public let fingerprint: Fingerprint
    public let keyID: String

    public init(
      signature: String,
      createdAt: Date,
      fingerprint: Fingerprint,
      keyID: String
    ) {
      self.signature = signature
      self.createdAt = createdAt
      self.fingerprint = fingerprint
      self.keyID = keyID
    }
  }
}
