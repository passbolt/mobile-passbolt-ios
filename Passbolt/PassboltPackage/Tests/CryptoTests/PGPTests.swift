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
import TestExtensions
import XCTest

@testable import Crypto

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PGPTests: XCTestCase {

  var pgp: PGP!

  override func setUp() {
    super.setUp()
    pgp = .gopenPGP()
  }

  override func tearDown() {
    pgp = nil
    super.tearDown()
  }

  func test_encryptionWithSigning_withCorrectKey_succeeds() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    let passphrase: Passphrase = "Secret"

    let output: Result<String, Error> = pgp.encryptAndSign(
      input,
      passphrase,
      privateKey,
      publicKey
    )

    XCTAssertSuccessNotEqual(output, input)
  }

  func test_encryptionWithSigning_WithIncorrectPassphraseSigning_fails() {
    let input: String = ""
    let passphrase: Passphrase = "SomeInvalidPassphrase"

    let output: Result<String, Error> = pgp.encryptAndSign(
      input,
      passphrase,
      privateKey,
      publicKey
    )
    do {
      _ = try output.get()
    }
    catch {
      print(type(of: (error as? PGPIssue)?.underlyingError))
    }

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PassphraseInvalid.self
    )
  }

  func test_decryptionAndVerification_withCorrectPassphrase_succeeds() throws {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "Secret"

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      publicKey
    )

    let verified: PGP.VerifiedMessage = try output.get()
    XCTAssertEqual(verified.content, "passbolt\n")
    // The returned signer metadata must correspond to the verifying key.
    XCTAssertEqual(verified.signature.fingerprint.rawValue.uppercased(), fingerprint.rawValue)
    XCTAssertFalse(verified.signature.keyID.isEmpty)
  }

  func test_decryptionAndVerification_withInvalidPassphrase_fails() {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "InvalidPasshrase"

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      publicKey
    )

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PassphraseInvalid.self
    )
  }

  func test_decryptionAndVerification_withCorruptedInputData_fails() {
    // 'Passbolt'
    let input: String = """
      -----BEGIN PGP MESSAGE-----
      CORRUPTED DATA SHOULD FAIL
      -----END PGP MESSAGE-----
      """
    let passphrase: Passphrase = "Secret"

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      publicKey
    )

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: Unidentified.self
    )
  }

  func test_decryptionAndVerification_withSignatureInvalidForVerifyTime_fails() {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "Secret"
    pgp.setTimeOffset(-631_152_000)  // ~20 years

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      publicKey
    )

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: Unidentified.self
    )
  }

  func test_decryptionWithoutVerifying_withSignatureInvalidForVerifyTime_stillSucceeds() {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "Secret"
    pgp.setTimeOffset(-631_152_000)

    let output: Result<String, Error> = pgp.decrypt(input, passphrase, privateKey)

    XCTAssertSuccessEqual(output, "passbolt\n")
  }

  func test_decryptionAndVerification_withFreshSignatureAndSlightlyNegativeOffset_succeeds() throws {
    // Regression for spurious "signature expired" failures: verifying a freshly created
    // signature with a slightly negative time offset (e.g. -1 from whole-second truncation)
    // must still succeed thanks to the clock-skew tolerance.
    let passphrase: Passphrase = "Secret"
    guard case Result.success(let freshlySignedCiphertext) =
      pgp.encryptAndSign("passbolt", passphrase, privateKey, publicKey)
    else {
      return XCTFail("Encryption failed")
    }

    pgp.setTimeOffset(-1)

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      freshlySignedCiphertext,
      passphrase,
      privateKey,
      publicKey
    )

    let verified: PGP.VerifiedMessage = try output.get()
    XCTAssertEqual(verified.content, "passbolt")
  }

  func test_decryptionAndVerification_withUnsignedMessage_fails() {
    let passphrase: Passphrase = "Secret"
    guard case Result.success(let unsignedCiphertext) = pgp.encrypt("passbolt", publicKey) else {
      return XCTFail("Encryption failed")
    }

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      unsignedCiphertext,
      passphrase,
      privateKey,
      publicKey
    )

    XCTAssertFailure(output)
  }

  func test_decryptionAndVerification_withSignatureFromUntrustedKey_fails() {
    // The message decrypts correctly (it is encrypted to our recipient key) and carries a valid
    // signature from our key, while verification is requested against a different, untrusted
    // public key. The signer is not in the verification set, so `signatureError()` must report it
    // and `decryptAndVerify` must not return it as a verified message.
    let input: String = signedCiphertext
    let passphrase: Passphrase = "Secret"

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      otherPublicKey
    )

    XCTAssertFailure(output)
  }

  func test_decryptionAndVerification_withSignatureFromSigningSubkey_succeeds() throws {
    // Regression: the verification key delegates signing to a dedicated [S] subkey, so the
    // signature's issuer fingerprint is the subkey's, not the key's primary fingerprint. The
    // message must still verify, and the reported signer fingerprint must be the subkey's.
    let input: String = subkeySignedCiphertext
    let passphrase: Passphrase = "Secret"

    let output: Result<PGP.VerifiedMessage, Error> = pgp.decryptAndVerify(
      input,
      passphrase,
      privateKey,
      subkeySignerPublicKey
    )

    let verified: PGP.VerifiedMessage = try output.get()
    XCTAssertEqual(verified.content, "passbolt")
    XCTAssertEqual(
      verified.signature.fingerprint.rawValue.uppercased(),
      subkeySignerSubkeyFingerprint.rawValue
    )
    XCTAssertNotEqual(
      verified.signature.fingerprint.rawValue.uppercased(),
      subkeySignerPrimaryFingerprint.rawValue
    )
  }

  func test_verifyMessage_withTamperedSignature_fails() {
    // Start from a correctly signed cleartext message and corrupt a few bytes inside the armored
    // signature block, leaving the signed payload ("passbolt") intact. The cryptographic check
    // over the tampered signature must fail.
    let tamperedMessage: String = signedMessage.replacingOccurrences(
      of: "8D0gOUXjEOa8v",
      with: "8D0gOUXAAOa8v"
    )
    // A point in time when the signing key is valid, matching the happy-path verify tests.
    let verifyTime: Int64 = 1_682_603_755
    // Sanity check: the tampering actually modified the message.
    XCTAssertNotEqual(tamperedMessage, signedMessage)

    let output: Result<String, Error> = pgp.verifyMessage(tamperedMessage, publicKey, verifyTime)

    XCTAssertFailure(output)
  }

  func test_verifyMessage_withTamperedCleartext_fails() {
    // Alter the signed payload while leaving the signature block intact. The signature no longer
    // matches the (modified) cleartext, so verification must fail.
    let tamperedMessage: String = signedMessage.replacingOccurrences(
      of: "passbolt",
      with: "PASSBOLT"
    )
    let verifyTime: Int64 = 1_682_603_755
    XCTAssertNotEqual(tamperedMessage, signedMessage)

    let output: Result<String, Error> = pgp.verifyMessage(tamperedMessage, publicKey, verifyTime)

    XCTAssertFailure(output)
  }

  func test_verifyMessage_withSignatureFromUntrustedKey_fails() {
    // The message is correctly signed by our key, but verification is requested against a
    // different, untrusted public key. The signer is not in the verification set, so it must not
    // be reported as verified.
    let input: String = signedMessage
    let verifyTime: Int64 = 1_682_603_755

    let output: Result<String, Error> = pgp.verifyMessage(input, otherPublicKey, verifyTime)

    XCTAssertFailure(output)
  }

  func test_verifyMessage_withSignatureFromSigningSubkey_succeeds() {
    // Regression: the verification key delegates signing to a dedicated [S] subkey, so the
    // signature's issuer fingerprint differs from the key's primary fingerprint. A valid signature
    // from such a key must still verify rather than be rejected as "not the expected key".
    let input: String = subkeySignedMessage
    // Disable the time check: the fixture is signed with a freshly generated, non-expiring key.
    let verifyTime: Int64 = 0

    let output: Result<String, Error> = pgp.verifyMessage(input, subkeySignerPublicKey, verifyTime)

    XCTAssertSuccessEqual(output, "passbolt")
  }

  func test_verifyMessage_withEmptyVerificationKey_fails() {
    let input: String = signedMessage
    let verifyTime: Int64 = 1_682_603_755

    let output: Result<String, Error> = pgp.verifyMessage(input, "", verifyTime)

    XCTAssertFailure(output)
  }

  func test_encryptionWithoutSigning_withProperInputData_success() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    let passphrase: Passphrase = "Secret"

    guard case Result.success(let encrypted) = pgp.encrypt(input, publicKey) else {
      XCTFail("Encryption failed")
      return
    }

    let decryptionOutput: Result<String, Error> = pgp.decrypt(
      encrypted,
      passphrase,
      privateKey
    )

    XCTAssertNotEqual(encrypted, input)
    XCTAssertSuccessEqual(decryptionOutput, input)
  }

  func test_encryptionWithoutSigning_withEmptyKey_failure() {
    let input: String = "The quick brown fox jumps over the lazy dog"

    let output: Result<String, Error> = pgp.encrypt(input, "")

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: Unidentified.self
    )
  }

  func test_decryptionWithoutVerifying_withCorrectPassphrase_succeeds() {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "Secret"

    let output: Result<String, Error> = pgp.decrypt(input, passphrase, privateKey)

    XCTAssertSuccessEqual(output, "passbolt\n")
  }

  func test_decryptionWithoutVerifying_withInvalidPassphrase_fails() {
    let input: String = signedCiphertext
    let passphrase: Passphrase = "InvalidPasshrase"

    let output: Result<String, Error> = pgp.decrypt(
      input,
      passphrase,
      privateKey
    )

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PassphraseInvalid.self
    )
  }

  func test_signMessage_withCorrectInputData_succeeds() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    let passphrase: Passphrase = "Secret"

    let output: Result<String, Error> = pgp.signMessage(
      input,
      passphrase,
      privateKey
    )

    guard case Result.success(let message) = output else {
      return XCTFail("Invalid value")
    }

    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNED MESSAGE-----"))
    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNATURE-----"))
    XCTAssertTrue(message.contains("-----END PGP SIGNATURE-----"))
    XCTAssertTrue(message.contains(input))
  }

  func test_signMessage_withEmptyMessage_succeeds() {
    let input: String = ""
    let passphrase: Passphrase = "Secret"

    let output: Result<String, Error> = pgp.signMessage(
      input,
      passphrase,
      privateKey
    )

    guard case Result.success(let message) = output else {
      return XCTFail("Invalid value")
    }

    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNED MESSAGE-----"))
    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNATURE-----"))
    XCTAssertTrue(message.contains("-----END PGP SIGNATURE-----"))
  }

  func test_signMessage_withInvalidPassphrase_fails() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    let passphrase: Passphrase = "InvalidPasshrase"

    let output: Result<String, Error> = pgp.signMessage(
      input,
      passphrase,
      privateKey
    )

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PassphraseInvalid.self
    )
  }

  func test_verifyMessage_withCorrectylySignedInputAndDisableTimeCheck_succeeds() {
    let input: String = signedMessage
    let verifyTime: Int64 = 0

    let output: Result<String, Error> = pgp.verifyMessage(input, publicKey, verifyTime)

    XCTAssertSuccessEqual(output, "passbolt")
  }

  func test_verifyMessage_withEmptyInputData_fails() {
    let input: String = ""
    let verifyTime: Int64 = 0

    let output: Result<String, Error> = pgp.verifyMessage(input, publicKey, verifyTime)

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: DataInvalid.self
    )
  }

  func test_verifyMessage_withCorrectlySignedInputAndEnabledTimeCheck_succeeds() {
    let input: String = signedMessage
    // A certain point in time when the key is valid
    let verifyTime: Int64 = 1_682_603_755

    let output: Result<String, Error> = pgp.verifyMessage(input, publicKey, verifyTime)

    XCTAssertSuccessEqual(output, "passbolt")
  }

  func test_verifyMessage_withCorrectlySignedInputAndInvalidVerifyTime_fails() {
    let input: String = signedMessage
    // Distant past - signature should be expired
    let verifyTime: Int64 = 1_682_603_135

    let output: Result<String, Error> = pgp.verifyMessage(input, publicKey, verifyTime)

    XCTAssertFailureUnderlyingError(output, matches: Unidentified.self)
  }

  func test_verifyPassphrase_withCorrectPassphrase_succeeds() {
    let passphrase: Passphrase = "Secret"

    let output: Result<Void, Error> = pgp.verifyPassphrase(privateKey, passphrase)

    XCTAssertSuccess(output)
  }

  func test_verifyPassphrase_withIncorrectInputData_fails() {
    let passphrase: Passphrase = "InvalidPassphrase"

    let output: Result<Void, Error> = pgp.verifyPassphrase(privateKey, passphrase)

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PassphraseInvalid.self
    )
  }

  func test_verifyPublicKeyFingerprint_withCorrectKeyAndFingerprint_succeeds() {
    let output: Result<Bool, Error> = pgp.verifyPublicKeyFingerprint(publicKey, fingerprint)

    XCTAssertSuccessEqual(output, true)
  }

  func test_verifyPublicKeyFingerprint_withIncorrectKey_fails() {
    let output: Result<Bool, Error> = pgp.verifyPublicKeyFingerprint("INCORRECT_KEY", fingerprint)

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PGPFingerprintInvalid.self
    )
  }

  func test_verifyPublicKeyFingerprint_withCorrectKeyAndIncorrectFingerprint_fails() {
    let output: Result<Bool, Error> = pgp.verifyPublicKeyFingerprint(publicKey, "INCORRECT_FINGERPRINT")

    XCTAssertSuccessEqual(output, false)
  }

  func test_extractFingerprint_succeeds_withCorrectPublicKey() {
    let output: Result<Fingerprint, Error> = pgp.extractFingerprint(publicKey)

    XCTAssertSuccessEqual(output, fingerprint)
  }

  func test_extractFingerprint_fails_withEmptyPublicKey() {
    let output: Result<Fingerprint, Error> = pgp.extractFingerprint(.init(rawValue: ""))

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PGPFingerprintInvalid.self
    )
  }

  func test_extractFingerprint_fails_withCorruptedPublicKey() {
    let output: Result<Fingerprint, Error> = pgp.extractFingerprint(corruptedPublicKey)

    XCTAssertFailureUnderlyingError(
      output,
      root: PGPIssue.self,
      matches: PGPFingerprintInvalid.self
    )
  }

  func test_readCleartextMessage_succeeds_withCorrectPGPMessage() {
    if let messageData = signedMessage.data(using: .utf8) {
      let output: Result<String, Error> = pgp.readCleartextMessage(messageData)
      XCTAssertSuccessEqual(output, signedMessage)
    }
  }

  func test_readCleartextMessage_succeeds_withNonPGPMessage() {
    if let messageData = "passbolt".data(using: .utf8) {
      let output: Result<String, Error> = pgp.readCleartextMessage(messageData)
      XCTAssertFailureUnderlyingError(
        output,
        root: PGPIssue.self,
        matches: PGPClearTextMessageInvalid.self
      )
    }
  }

  func test_isPGPSignedClearMessage_succeeds_withSignedPGPMessage() {
    let output: Bool = pgp.isPGPSignedClearMessage(signedMessage)
    XCTAssertTrue(output)
  }

  func test_isPGPSignedClearMessage_succeeds_withoutSignedPGPMessage() {
    let output: Bool = pgp.isPGPSignedClearMessage("passbolt")
    XCTAssertTrue(!output)
  }

  func test_decryptingWithSessionKey_succeeds_withCorrectInput() throws {
    let result: String? = try pgp.decryptWithSessionKey(signedCiphertext, sessionKey)
    XCTAssertEqual(result, "passbolt\n")
  }

  // MARK: Test data

  private let publicKey: ArmoredPGPPublicKey =
    """
    -----BEGIN PGP PUBLIC KEY BLOCK-----

    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
    =EqaW
    -----END PGP PUBLIC KEY BLOCK-----
    """

  private let corruptedPublicKey: ArmoredPGPPublicKey =
    """
    -----BEGIN PGP PUBLIC KEY BLOCK-----

    mQINBGRKeUoBEADe10E6oWTG6ab84iKyrB5Ne4UKWmpyEL4LIg7jl9gRXqZE0e83
    KLi2faCquaXFMd29B4lJa37cNrQ3UZ0ojhxx8qjXetufTHmE+RPU36JYpP2J7wVh
    bYRhrlprybuLfThB/1UbggFBlGhi3jwlIGtjlLWcLXjcBlZs7dzWMUnfW2Klarve
    G9gmhTc6T1JcJClXYi/FEK5YDUrf9HrP+AeIFZhT9wM70Z5dM68lqPorWbcnhvW5
    1Nd2SRAi7htI1eZ62wa4Os+IlnGMQmBQXZN4CdkFgfE1Pz6Zv0cjHsFH33GsoLGE
    VSDtYi0dvB7b9d+/MjaeEarItPLnshbj8bHItE3vEQGKvNHOUwp9G3/K3BFaAnU/
    OzuqHl9dQXzrSevi25ttftMp9AFT6xeB0XS43D/A/Qnqj4SrFei/xzb0a/U/AzGK
    3qjctzLHm3U8GH6cLJoCbE3ue7wDBxN2EbSR4xNKucl/fLTRtJdkXvCAKpl1W0B0
    dPkNpykAwRzJk8+XmsZWOprgIYxVV4TUZ0APhVZHmvwL553MQrCrBKY6pjsbpsPj
    nqUaK/FlCoikpZmuloT7YKAkboEW5lAmRgWe33hkN8zR+uaNuJhoM+l2dJIYRWVX
    RzKOhxpyJIvhP2cbz3/22LQ+iWOa9TW9EdDnGxnjCh/RZ7/zJ3s9dc9TTwARAQAB
    tENUZXN0IChGb3IgdW5pdCB0ZXN0cyBvbmx5IC0gcHVibGljbHkgYXZhaWxhYmxl
    1oi6R4uQuGMqmAOKnwHiWnm+VVFv/ZX8AGea1NLDUxLjnjnqO5/jw8DTuoxp+80Z
    FirqxFtR6FsZxsaLrsc7wwRjPn6yXCwp3hSHsCnTHQ0pFD+GGDFLiWssCVs80rYX
    yJqXlhxIE/q8x7XGGXpo1pr4WQGE3/nkhtxecJfb0tIpug==
    =EqaW
    -----END PGP PUBLIC KEY BLOCK-----
    """

  // A different, valid public key (Ada Lovelace test key) used as an untrusted verification key.
  private let otherPublicKey: ArmoredPGPPublicKey =
    """
    -----BEGIN PGP PUBLIC KEY BLOCK-----

    mQINBFXHTB8BEADAaRMUn++WVatrw3kQK7/6S6DvBauIYcBateuFjczhwEKXUD6T
    hLm7nOv5/TKzCpnB5WkP+UZyfT/+jCC2x4+pSgog46jIOuigWBL6Y9F6KkedApFK
    xnF6cydxsKxNf/V70Nwagh9ZD4W5ujy+RCB6wYVARDKOlYJnHKWqco7anGhWYj8K
    KaDT+7yM7LGy+tCZ96HCw4AvcTb2nXF197Btu2RDWZ/0MhO+DFuLMITXbhxgQC/e
    aA1CS6BNS7F91pty7s2hPQgYg3HUaDogTiIyth8R5Inn9DxlMs6WDXGc6IElSfhC
    nfcICao22AlM6X3vTxzdBJ0hm0RV3iU1df0J9GoM7Y7y8OieOJeTI22yFkZpCM8i
    tL+cMjWyiID06dINTRAvN2cHhaLQTfyD1S60GXTrpTMkJzJHlvjMk0wapNdDM1q3
    jKZC+9HAFvyVf0UsU156JWtQBfkE1lqAYxFvMR/ne+kI8+6ueIJNcAtScqh0LpA5
    uvPjiIjvlZygqPwQ/LUMgxS0P7sPNzaKiWc9OpUNl4/P3XTboMQ6wwrZ3wOmSYuh
    FN8ez51U8UpHPSsI8tcHWx66WsiiAWdAFctpeR/ZuQcXMvgEad57pz/jNN2JHycA
    +awesPIJieX5QmG44sfxkOvHqkB3l193yzxu/awYRnWinH71ySW4GJepPQARAQAB
    tB9BZGEgTG92ZWxhY2UgPGFkYUBwYXNzYm9sdC5jb20+iQJOBBMBCgA4AhsDBQsJ
    CAcDBRUKCQgLBRYCAwEAAh4BAheAFiEEA/YOlY9MspcjrN92E1O1sV2bBU8FAl0b
    mi8ACgkQE1O1sV2bBU+Okw//b/PRVTz0/hgdagcVNYPn/lclDFuwwqanyvYu6y6M
    AiLVn6CUtxfU7GH2aSwZSr7D/46TSlBHvxVvNlYROMx7odbLgq47OJxfUDG5OPi7
    LZgsuE8zijCPURZTZu20m+ratsieV0ziri+xJV09xJrjdkXHdX2PrkU0YeJxhE50
    JuMR1rf7EHfCp45nWbXoM4H+LnadGC1zSHa1WhSJkeaYw9jp1gh93BKD8+kmUrm6
    cKEjxN54YpgjFwSdA60b+BZgXbMgA37gNQCnZYjk7toaQClUbqLMaQxHPIjETB+Z
    jJNKOYn740N2LTRtCi3ioraQNgXQEU7tWsXGS0tuMMN7w4ya1I6sYV3fCtfiyXFw
    fuYnjjGzn5hXtTjiOLJ+2kdy5OmNZc9wpf6IpKv7/F2RUwLsBUfH4ondNNXscdkB
    6Zoj1Hxt16TpkHnYrKsSWtoOs90JnlwYbHnki6R/gekYRSRSpD/ybScQDRASQ0aO
    hbi71WuyFbLZF92P1mEK5GInJeiFjKaifvJ8F+oagI9hiYcHgX6ghktaPrANa2De
    OjmesQ0WjIHirzFKx3avYIkOFwKp8v6KTzynAEQ8XUqZmqEhNjEgVKHH0g3sC+EC
    Z/HGLHsRRIN1siYnJGahrrkNs7lFI5LTqByHh52bismY3ADLemxH6Voq+DokvQn4
    HxS5Ag0EVcdMHwEQAMFWZvlswoC+dEFISBhJLz0XpTR5M84MCn19s/ILjp6dGPbC
    vlGcT5Ol/wL43T3hML8bzq18MRGgkzhwsBkUXO+E7jVePjuGFvRwS5W+QYwCuAmw
    DijDdMhrev1mrdVK61v/2U9kt5faETW8ZIYIvAWLaw/lMHbVmKOa35ZCIJWcNsrv
    oro2kGUklM6Nq1JQyU+puGPHuvm+1ywZzpAH5q55pMgfO+9JjMU3XFs+eqv6LVyA
    /Y6T7ZK1H8inbUPm/26sSvmYsT/4xNVosC/ha9lFEAasz/rbVg7thffje4LWOXJB
    o40iBTlHsNbCGs5BfNC0wl719JDA4V8mwhGInNtETCrGwg3mBlDrk5jYrDq5IMVk
    yX4Z6T8Fd2fLHmUr2kFc4vC96tGQGhNrbAa/EeaAkWMeFyp/YOW0Z3X2tz5A+lm+
    qevJZ3HcQd+7ca6mPTrYSVVXhclwSkyCLlhRJwEwSxrn+a2ZToYNotLs1uEy6tOL
    bIyhFBQNsR6mTa2ttkd/89wJ+r9s7XYDOyibTQyUGgOXu/0l1K0jTREKlC91wKkm
    dw/lJkjZCIMc/KTHiB1e7f5NdFtxwErToEZOLVumop0FjRqzHoXZIR9OCSMUzUmM
    spGHalE71GfwB9DkAlgvoJPohyiipJ/Paw3pOytZnb/7A/PoRSjELgDNPJhxABEB
    AAGJAjYEGAEKACACGwwWIQQD9g6Vj0yylyOs33YTU7WxXZsFTwUCXRuaPgAKCRAT
    U7WxXZsFTxX0EADAN9lreHgEvsl4JK89JqwBLjvGeXGTNmHsfczCTLAutVde+Lf0
    qACAhKhG0J8Omru2jVkUqPhkRcaTfaPKopT2KU8GfjKuuAlJ+BzH7oUq/wy70t2h
    sglAYByv4y0emwnGyFC8VNw2Fe+Wil2y5d8DI8XHGp0bAXehjT2S7/v1lEypeiiE
    NbhAnGG94Zywwwim0RltyNKXOgGeT4mroYxAL0zeTaX99Lch+DqyaeDq94g4sfhA
    VvGT2KJDT85vR3oNbB0U5wlbKPa+bUl8CokEDjqrDmdZOOs/UO2mc45V3X5RNRtp
    NZMBGPJsxOKQExEOZncOVsY7ZqLrecuR8UJBQnhPd1aoz3HCJppaPI02uINWyQLs
    CogTf+nQWnLyN9qLrToriahNcZlDfuJCRVKTQ1gw1lkSN3IZRSkBuRYRe05US+C6
    8JMKHP+1XMKMgQM2XR7r4noMJKLaVUzfLXuPIWH2xNdgYXcIOSRjiANkIv4O7lWM
    xX9vD6LklijrepMl55Omu0bhF5rRn2VAubfxKhJs0eQn69+NWaVUrNMQ078nF+8G
    KT6vH32q9i9fpV38XYlwM9qEa0il5wfrSwPuDd5vmGgk9AOlSEzY2vE1kvp7lEt1
    Tdb3ZfAajPMO3Iov5dwvm0zhJDQHFo7SFi5jH0Pgk4bAd9HBmB8sioxL4Q==
    =Kwft
    -----END PGP PUBLIC KEY BLOCK-----
    """

  private let fingerprint: Fingerprint = .init(rawValue: "A3A3D9487C5771103D5C91CC6842865C83872670")

  // A key whose signing capability is delegated to a dedicated signing subkey: the primary key is
  // certify-only ([C]) and a separate [S] subkey produces signatures. Signatures from such a key
  // carry the *subkey's* fingerprint as their issuer, not the primary's — the regression case for
  // signer-fingerprint verification. Generated with a fixed 2023-04-27 creation time so the fixture
  // signatures stay valid against the real `now()` used by the gopenPGP implementation under test.
  private let subkeySignerPrimaryFingerprint: Fingerprint = .init(
    rawValue: "A459EDB7714E2C74EC592B4C8D6C70B693FAD9E8"
  )
  private let subkeySignerSubkeyFingerprint: Fingerprint = .init(
    rawValue: "39ECE05AEF46437145E602477AE71E8A517EB10A"
  )

  private let subkeySignerPublicKey: ArmoredPGPPublicKey =
    """
    -----BEGIN PGP PUBLIC KEY BLOCK-----

    mQENBGRKkasBCADHbnS5iDaeHov3GsWgGfOYd/9RJO5X1/C5Vg8ae9Bdafb5RNZW
    fcU0N2Ab/F3Am2mgLqLU73iEqhmy3SezKw5Nuzo8ZSdkdflvQGCzPSctNhrUOQ/b
    4g2au7NIMO7Z8HxLEuJBX0Sa19aGTMiQSC/l7YDHqhbEqZ/WnMIMboaX8DswUOGG
    grYygJkb/Y5RkSHCnNYUWPDJBXxABtifDhUYK8PwXzAtDMiymVi/JhOTJXmS/d8k
    AAOuuX92p+ciq3p9/9XmAXvjkLhtrxkJdETTReNYL1QpTd31chpqVfaMo72gBjHc
    xJVO+wEyak4PLcDpOY8+YeG5NuDwLBEyja7zABEBAAG0K1N1YmtleSBTaWduZXIg
    PHN1YmtleS1zaWduZXJAcGFzc2JvbHQudGVzdD6JAVEEEwEKADsWIQSkWe23cU4s
    dOxZK0yNbHC2k/rZ6AUCZEqRqwIbAQULCQgHAgIiAgYVCgkICwIEFgIDAQIeBwIX
    gAAKCRCNbHC2k/rZ6DdpB/96irV0Oqlt4Eg5ByqsA/X+D1ZiEG4TSy3JLuz3/IQH
    VjD4V0QVc1UxsBGPFD8FFMibGtOuL9u0XZkWVD50wFS5ESXtA3L00knVoR9bzjKD
    GCpEy4OYf4CP4MahLBelM5MSJiGWdNVMszxqjcz6HbI6+b7v6BHoLbUcaRR6ACEn
    vNEMfQdRxPad6oxFf7cdgwtJt/LZsIuoygQ7mJw+uasO6HCJMm7wyuVspiGRkEpJ
    +68cTCw7lO5JcsndBSNglZRfXEl+QqgsrLsLCSu6G9Co1St8VIgKfZdi5ZtL3N+i
    wVD8kw8E+ZTMaYLAac3jHJ/yrUGxopRSYfznouIUXqF5uQENBGRKkasBCADObYRI
    AWR3cr9P8yxurJ/T/Z8VcH3aoCe3HyLyXIVmWEXkXa5moBMA/3jxG/Z7yAsDbNRH
    GMNe7qclOPhhHzHgVpynrSC7tv26IEmj3nA4bnuHWQJRs31dR0L8wsrIai7uwQqt
    bn/Th9jzgHktymv5yTMlSJy6TMw3ykzwzz1On998RvZwMp9TvxiCjl1rqzR1QNRN
    4YwPSL/t2ouKkdqdFzy3DCc29+5zDufiEXsszvk4P9SsThPbCC8N0BW2dSPCXBj8
    N2W8JNKNjGKahjmqZp4AOo8j+0GmI+FDHEkcGJQ7aLDeUmxb+bKAOOOHuM8KzdR0
    8Iq1EjboPVU6szS/ABEBAAGJAmwEGAEKACAWIQSkWe23cU4sdOxZK0yNbHC2k/rZ
    6AUCZEqRqwIbAgFACRCNbHC2k/rZ6MB0IAQZAQoAHRYhBDns4FrvRkNxReYCR3rn
    HopRfrEKBQJkSpGrAAoJEHrnHopRfrEKUNAH/0qAx7sn+oC80euIJTeKb2mlC0RD
    a4MfHL4nHBn1bXR4YtFqPPJYB+cN98nLlG3Nj9F6MeFZ2AtNm9GIXQMuNNXZm5UC
    k51dbT994XzGFuAyLN5TyCsH/wohQztXsx28UyjEojdSlzuF2XUa4CffvX88yx1C
    zXOAXZUER5Qvj0kr+NABHYlacsxHSWOCK1CYP1GCikV6uWk7Bw5y6TQQ3VSgM00e
    7Rd5LwRuFS+oU/LmDVhlyF3+gNmGIo4Wjg3EMbZhQyuPXT0dHtB6hlYHeV0vUC31
    FSsjDWUqj0kCvCwbSJntkgxdSuEmEWcpeZLYymNe4mts2St/KoGbFxSQ44FcDQf/
    cp2/gdNCIXN4VQMNc0oA6pa5sT1LlGsArZFUA0iOwGjmP8jimi9OTPXCBXSuS5lH
    1UqOJgWC+9IFkyk/e2njrlrKrw5p65M8fi9lgKEBxBroB1YZQ1tdSlf+MH+s9v+L
    e6y4Fm0DoufM9r1Mrk8wWNeabW4KPLQIhE7nAniHn8s8IDqPmvINA9hlNBWbjL6Y
    xKxM9vcYTckEGnU6Q+VYvPV3k2i5SsZpanB0CxNScFrS6sn6CIOFg7fo+81ErQts
    JJKfGDkTHcpUaRH16eqEDyfsI5eZ74tGvegdle1DJ+iZmnFeo9nLL3cNO600Ju79
    9T61KbKi733Tmd6CNMosgg==
    =ELV7
    -----END PGP PUBLIC KEY BLOCK-----
    """

  // "passbolt" clear-signed by the signing subkey of `subkeySignerPublicKey`.
  private let subkeySignedMessage: String =
    """
    -----BEGIN PGP SIGNED MESSAGE-----
    Hash: SHA512

    passbolt
    -----BEGIN PGP SIGNATURE-----

    iQEzBAEBCgAdFiEEOezgWu9GQ3FF5gJHeuceilF+sQoFAmRKkasACgkQeuceilF+
    sQqDUAgAiJiVvUtaK43VWOhfNt3U3F52rfsBTCGVQ1Cz8IhWnKkbW0gZ3yhYC/N+
    R1qmjcSFQ0NzK7NBoHgPxkLiK9oz7ck8RmF3VQfjuLVw9yrKlAQKyl/SFArMXQLB
    HNSA9f/CWOC4vwAI7r4yno8vBMJGVOxIVX5RrWKVcdq2jr1APXy3Raz7+dxS7cXh
    MLuFhxL79i3E3nFvsrkF4uMYAFgIBhOXsUnP2rnUdmkLaszxA/zVQnxJP0ToLX2b
    2mih79MBcoDqoQfWeMUyFhhjwhR7dqRY9a51IYgzK78oum4OCp5tYw53Bgz2oaXk
    tnRmq+j0YrNEDN1H32WnUBBS/jp2Ew==
    =9tZG
    -----END PGP SIGNATURE-----
    """

  // "passbolt" encrypted to the `publicKey` recipient and signed by the signing subkey of
  // `subkeySignerPublicKey`; decryptable with `privateKey` and verifiable with `subkeySignerPublicKey`.
  private let subkeySignedCiphertext: String =
    """
    -----BEGIN PGP MESSAGE-----

    hQIMA2YpnJitJuEuARAAi3SFnoWsSN8TZPhYmpDSOh4pZ5mUJieqt+ylb5n5W5gM
    nQMNLcAHz4iz9BVBgAQS6UdClCXI5XJQqmBxlA5mbFqUhU9q1FtEiq2kl5Fo93pT
    e+Ww7AcPSiTk05gDmleRxpm0C3DyKpBgoKe92g+ZzBLZxxOrwt9+8BMNArngi3wV
    1UWGhf64n2jzQWRxIGW5L+3Fc6eZflPoX8yl7JofR+bLsQkhChkhshvxf9R33ZWw
    TtbjD9xvqj8RSMlyIGsjwesaFFLd/SCn+dJv3YhsFPknqTUso6J0OJ2BXruGOPEY
    46FzFlV4qhl/hVSFDf6/dMQsW+JDUF0n4neuPSltfp3QE32byyYbE4IF2AOzGaqz
    vC6UOquTiobJqVK3oN+In5733QIRPNhduAQsKu4QdKo+D2R7DqIEOy3M3JYxycJK
    uX8sUdjyfhRPorVuO+FriUpYwER4jjRP/CWGImDGuc+cVz/w41iJOg2itPbIa2be
    DIWpsuEDBI5+EZIoRD+8lUqzEFy2MTc2BnCC6ZB7UBQx63p6CAzF1IhLGLdR981P
    StEgRqcOpIlHykjXjxbUK2/DqPrEw52PJUM5/qaVkll8wbHhxrv/d4iOqpJxVJz7
    UeZoTxHYWIv7PCmhhSq7biby1aTqbto9EMGuL4exgHm7q400DR1c/TKoz0TsTm3U
    wOkBCQIQ1kqT/noEF/pvFiCG5wWp1/SLo1n2ToCY1qPIhiTzoQbQ/X6utNmZcRA2
    mNw93a3xJvy8mYXiLjH811Rw9DqXEx9CDzVTE2Z4ORWRmF38bZVSnqDX9mPEcqdJ
    Vmm+HdiE9FTZjvnzcMjK3l2NVHr61XtWvgAjUDMwd0RWvmKiR+iqCQ+wVNoQCRWv
    NjeAoL7yLLs+50r0PO05vgIm0iEXG+FKRKoaTU421DqaDWlzUztJspdr5ghy3xFM
    6bG4QW4VMDpq1sdL1+88RQ7S5CqDXHCP07EsBZIINwp35BaJGYVrzwRqMwUbluXz
    TbYR+O+/F4lKpuqdyAQitQhJR/5ZR+RsaZlJKJwOhP5yFJju33PCCEN2Y04llwpJ
    2IvFVA9VQlZPz8j9yu29lN6Nhm0Hg9wfikFaMOZyDAC50OoUU9IYQFNXI/n0sdJs
    i837r0yTU6SHEIuhqxfoqLySXQVVsOq20QwVVOtUYCddEW7rOBSOZowjZbTksnwJ
    DLVi2l5b5AGCdbtmpXl078Kuz/UjnJPUgGLBpg8COTDBujjfnn/PnycmfA==
    =FR6h
    -----END PGP MESSAGE-----
    """

  private let privateKey: ArmoredPGPPrivateKey =
    """
    -----BEGIN PGP PRIVATE KEY BLOCK-----

    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
    Xk5RgPwt0vy4+Mg6aIDYYu+toin2fw9glmBov5W6WMax1gB6RwAl94mVS5laENwu
    TZYkZCHIi/mAwoX2PxsmTEt3fABKzTaZxizEYKP0O/OXjp/v8IAvSNCpokWegRoc
    mvR1h9wrHHO18MrtCC4S0EnXUpEJhxzE6e9RCe7uYMG7CO8naeLh8LRDVGVzdCAo
    Rm9yIHVuaXQgdGVzdHMgb25seSAtIHB1YmxpY2x5IGF2YWlsYWJsZSkgPHRlc3RA
    cGFzc2JvbHQuY29tPokCUQQTAQgAOxYhBKOj2Uh8V3EQPVyRzGhChlyDhyZwBQJk
    SnlKAhsDBQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheAAAoJEGhChlyDhyZwgzcQ
    AJaG4It0GnWzJnv8EtgMvPbTFo+kJhFXdIAPPa7iO6xkrSH3jL/yUfgDySHuEQC1
    zqgPl5WrlX1N7ZZNJ9rgVo1jDPnNsxZj+30K1lrYMFui0kgCWJnoH9Qv4nnuZvmf
    MfEY61G+v1NkTleOQuyfed72t6cOOABMyHvmCHvxtxWAg/ZsjcIK3u6Tk/oWMm2t
    DBxOrKoevkSp8kvPFTZLi8Uo68SpdB/Z0bIee6FZH52lrOFkcP+i66mf0f4PMljN
    rN5HBceW0WNVdk/4g2Fvus7aac30kvot2qVAsEjY6caj6TVhz6gb6YMmD9ndx4fv
    pi1zHAFmNjsGgKQbYOMDJu3TYh+Pc7nZTgcihlCpLzN5i9R2TWXePfAxRJRw8soz
    W/3yqW5TA4oCiFiJ1eZNez/BRo0uQsKqjRyKd8sEa2rvLtjWKHeUBFPbRAxo8Yxs
    c2bPH56U5UPxvdViQnIhzUYorgmaaVFI/nZ7N2G1qgGw2o3JEc4TrwisjhFf5ACf
    ytPXz6Uu254Y3YjoGk6pPEt9o5aV2VjLVX3vnIFmyKRsz+n7a1m+O+fAe61qGQzD
    /w5dPHgFTIiSuMIQnBC/k2Pqr0YG2/FHzRdACv6jS4a8VExyNhlSG8V78re/ELBh
    iJAo6dhdjvG9yViuNPn6kYrKXS/6ATKblLwYMLl3JjWznQdFBGRKeUoBEADJ3Oa8
    2H33U7u6u/6mOc4L+qa8BC/EpiiBwb+gwcMJhRkglqprapKrU1Jj7SrxIAWrlUXX
    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
    mvhZAYTf+eSG3F5wl9vS0im6
    =l1OQ
    -----END PGP PRIVATE KEY BLOCK-----
    """

  // 'Passbolt\n'
  private let signedCiphertext: String =
    """
    -----BEGIN PGP MESSAGE-----

    hQIMA2YpnJitJuEuARAArmI9c/k48S+1RpwqhNtWEXpVuS5Z9SuVkvWsO7R/lhKd
    nfA9VcUHPhIKfEfDI522VAbY9wOaI/72XHgpUf0oq+qrL4ZXKAd9ncOTZyQn8+Aw
    KA9/TSLfOcQlARgy5mMTAq6UUuaopwwUk3rqHUaL+YMzBLL9NebhxuI5YEwYSDNt
    QZFZhmFnU/o/15XsG65prjN04BFn+cFmm66FLgUB97BA3VxWslxmv4kqqBfhY16Z
    kcrgrUlldCE6Le0Zx1p6bTH/1OUwsM7lItVUsCCQALvuWGe6l0SbpBNyB9Qf1l9J
    EzqiSRgmC8oYXJA+hJ3Vr+NImjOzv6YZA3c6w05TUqSnpCX8soTb1pNSHEcPF+04
    IvwVZ8ENzK3o8lsjYXqB7Ajw0dKHDBA8hd3ilDyaNy9AFIX6Uxl3P4dSvVHsLQJ9
    80XqFV5ABGv0TVwOVqkxJjJgDu/91MM54LQCFTQG/+jSgVus08qQMNoJYoX7YNsv
    Bj2TsigY5H0wE5ApiERtWyLxWAE19CHYygwf79j+d3NXKcI8kfZa8AujFhWwHK2c
    NPUUWvJtZpxqzCKzs8FuAiggxV6hUnPJiY0Vb4EE+uWxriesgxPJ0cX9AsJjpR1m
    G4AIBpKSzMJBx5ZlcijkWIYRxF0j33zej1Wz0frG/Di7o4XZXpnydjbyZfbOxlLU
    6QEJAhB6HUiC89jq+oBLsrDHEE5+HQ5lWUS3uLobpyPa9llHgEsTRqMxE4IgxAy/
    SOke9zF9Ey7aN/do6S6SV8ivhTNYhqPMSSM+CqnueEdo1ZzUgbUgFhIvrekUSif8
    VFu7q86N0eea8FJqPB8Cuzd4HioIIHFJN1A+MCjDl/KKzHtZaywjowcjiTa/+wPG
    lnkrMy5cbFjriIa5Gl/Djv/jKrZ8GcplfX9pV7sBfPdqdfZJOBMGP5PS6DQmEO8z
    f7/RnHhGreI5yLKnPaaHELLKerJjhQRgelLEYGwqA90rsJkFkWA3DNakqwnzn4Fn
    xQ/w5mTvM1J2KBnFYnE6NzLnmNEVPt5ckz0V1g6puFP+djk7sI873kRxgDwbpTdm
    VKtTthqOEty9g2AoDQOC/me9EyLlLbcbUbA2z1BjqRjuDz9mGbRFLhRxfm1H2qCl
    aqPS1lK/1BY3p6j3uNU9oE+15HkmRfF+rH4xM55cmV7vCBSeJcR5q14MeY4MJXsD
    FJZkGd2lYE66S4/tfb2yANQAmqmB5HmrYux/xeRJdHkVN5FwpOFtjV8wK/wXlCC7
    FpHJeh2VG9HXp/eKGD4BHr2hsM98XI7KcyKjH+seXRFmpUujUr00/Zjzf4DkkCP/
    7F7xsPgCRVuLTqDgnbge+sjnYhTRJJA+BhN4Pkk72VhSmoRBA+CP5pQFDGwYaTPa
    dfb0CywfD/esUqPdZw2QXD3OCtaOTnSYX4/gVBs3QW8ByIjP8Lv6JjlimgcIqL6N
    Qo+xovBes8vMMZNa661weY3jy/dQ6cW63W7JuEuNv61wo+E/qaZh76F+ZKJOQQr4
    6i6MK0hcjYBG7HrmFXhldLAQBxBKTypKPC8bDLCzSRf3OwWfBwou2HcwReM=
    =1IKI
    -----END PGP MESSAGE-----
    """

  private let signedMessage: String =
    """
    -----BEGIN PGP SIGNED MESSAGE-----
    Hash: SHA256

    passbolt
    -----BEGIN PGP SIGNATURE-----

    iQIzBAEBCAAdFiEEo6PZSHxXcRA9XJHMaEKGXIOHJnAFAmRKftgACgkQaEKGXIOH
    JnAWEg/8D0gOUXjEOa8vO3nFCvlGOzbgCYi3XqWonh+A6Bg6wjyB8pRyFBY5Q2Ij
    8rAt6q1GFNCtevpU3tWV7EE7oUpMb41TNyOmzFcSkQg89teyuz+eBhLx6WSZ/QWk
    +idC5FUawT/U2ua1kD09YrG60sj9W8DM0jqmX43deAbMfLeBSIbYiwmFOYax5Uit
    wiGDGkNx7yiwuHrBvqNhcZ+MpOI8QTw2q7vuO+7VfEmN7NugQHecbkReAdtobod4
    ux+XP+OgLfTdBHbUv8LL8HnCIj8HImfPV80NUUiwz3eC2cJDGrakaNd4cSbWy2FB
    t2TB/wj/7kzM+wkdNScVCuP1szcDx6mCD1Z5mGrbrVIZUeZJERdQD1mxyD+Cj2/x
    vmrj0zDUQ5mYy531wsDPij0+P76tHUDTPWDR0oOKyao0g4iBvCnoyvjDbzMPhSAi
    /X0pOFjpulWAjRMIpVPxabfLT+2boS1oLoADfhq/FgAnt7Rl2F1qctXkjwADTwS7
    LbTzPFh0eQYccGQ8CVznnXUej2RnqSR5GbUTJlouAhzIrr2TAILkuU8l5XuYOEco
    MfIs3dFgMUflT11ulApxXHWO2L9cTd0vpHXP3skGoKVMrCbA17bDLkkOh0oFijrB
    OfkGGAaTv9qNGBafKe16YWg1wjs0ZLGxkCSoF7er0ixpwoBa0Y8=
    =I81l
    -----END PGP SIGNATURE-----
    """

  private let sessionKey: SessionKey = "33991A2536F8A1D50DA44AC504F36C2FEDE5C6B1A170541DBAB74746DC5C30B1"
}
