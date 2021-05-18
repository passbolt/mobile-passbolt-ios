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
@testable import Crypto
import TestExtensions
import XCTest

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
// swiftlint:disable implicitly_unwrapped_optional
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
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<String, TheError> = pgp.encryptAndSign(
      input, passphrase, privateKey, publicKey
    )
    
    XCTAssertSuccessNotEqual(output, input)
  }

  func test_encryption_WithIncorrectPassphraseSigning_fails() {
    let input: String = ""
    let passphrase: String = "SomeInvalidPassphrase"
    
    let output: Result<String, TheError> = pgp.encryptAndSign(
      input, passphrase, privateKey, publicKey
    )
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid error")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_decryptionAndVerification_withCorrectPassphrase_succeeds() {
    let input: String = signedCiphertext
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<String, TheError> = pgp.decryptAndVerify(
      input, passphrase, privateKey, publicKey
    )
    
    XCTAssertSuccessEqual(output, "Passbolt\n")
  }
  
  func test_decryptionAndVerification_withCorruptedInputData_fails() {
    // 'Passbolt'
    let input: String = """
    -----BEGIN PGP MESSAGE-----
    CORRUPTED DATA SHOULD FAIL
    -----END PGP MESSAGE-----
    """
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<String, TheError> = pgp.decryptAndVerify(
      input, passphrase, privateKey, publicKey
    )
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid error")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_encryptionWithoutSigning_withProperInputData_success() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    
    let output: Result<String, TheError> = pgp.encrypt(input, privateKey)
    
    XCTAssertSuccessNotEqual(output, input)
  }
  
  func test_encryptionWithoutSigning_withEmptyKey_failure() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    
    let output: Result<String, TheError> = pgp.encrypt(input, "")
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid error")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_decryptionWithoutVerifying_withCorrectPassphrase_succeeds() {
    let input: String = signedCiphertext
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<String, TheError> = pgp.decrypt(input, passphrase, privateKey)
    
    XCTAssertSuccessEqual(output, "Passbolt\n")
  }
  
  func test_decryptionWithoutVerifying_withInvalidPassphrase_fails() {
    let input: String = signedCiphertext
    let passphrase: String = "InvalidPasshrase"
    
    let output: Result<String, TheError> = pgp.decrypt(
      input, passphrase, privateKey
    )
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid error")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_signMessage_withCorrectInputData_succeeds() {
    let input: String = "The quick brown fox jumps over the lazy dog"
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<String, TheError> = pgp.signMessage(
      input, passphrase, privateKey
    )
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.success(message) = output else {
      return XCTFail("Invalid value")
    }
    
    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNED MESSAGE-----"))
    XCTAssertTrue(message.contains("-----BEGIN PGP SIGNATURE-----"))
    XCTAssertTrue(message.contains("-----END PGP SIGNATURE-----"))
    XCTAssertTrue(message.contains(input))
  }
  
  func test_signMessage_withEmptyMessageAndPassphrase_fails() {
    let input: String = ""
    let passphrase: String = ""
    
    let output: Result<String, TheError> = pgp.signMessage(
      input, passphrase, privateKey
    )
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid error")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_verifyMessage_withCorrectylySignedInputAndDisableTimeCheck_succeeds() {
    let input: String = signedMessage
    let verifyTime: Int64 = 0
 
    let output: Result<String, TheError> = pgp.verifyMessage(input, publicKey, verifyTime)
    
    XCTAssertSuccessEqual(output, "Passbolt")
  }
  
  func test_verifyMessage_withEmptyInputData_fails() {
    let input: String = ""
    let verifyTime: Int64 = 0
 
    let output: Result<String, TheError> = pgp.verifyMessage(input, publicKey, verifyTime)
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid value")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.invalidInputDataError)
  }
  
  func test_verifyMessage_withCorrectlySignedInputAndEnabledTimeCheck_succeeds() {
    let input: String = signedMessage
    // A certain point in time when the key is valid
    let verifyTime: Int64 = 1_619_588_275
 
    let output: Result<String, TheError> = pgp.verifyMessage(input, publicKey, verifyTime)
    
    XCTAssertSuccessEqual(output, "Passbolt")
  }
  
  func test_verifyMessage_withCorrectlySignedInputAndInvalidVerifyTime_fails() {
    let input: String = signedMessage
    // Distant future - the keys should be expired by then
    let verifyTime: Int64 = .max
 
    let output: Result<String, TheError> = pgp.verifyMessage(input, publicKey, verifyTime)
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid value")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.pgpError)
  }
  
  func test_verifyPassphrase_withCorrectPassphrase_succeeds() {
    let passphrase: String = "SecretPassphrase"
    
    let output: Result<Void, TheError> = pgp.verifyPassphrase(privateKey, passphrase)
    
    guard case Result.success(_) = output else {
      return XCTFail("Invalid error")
    }
  }
  
  func test_verifyPassphrase_withIncorrectInputData_fails() {
    let passphrase: String = "InvalidPassphrase"
    
    let output: Result<Void, TheError> = pgp.verifyPassphrase(privateKey, passphrase)
    
    // swiftlint:disable:next explicit_type_interface
    guard case let Result.failure(error) = output else {
      return XCTFail("Invalid value")
    }
    
    XCTAssertEqual(error.identifier, TheError.ID.invalidPassphraseError)
  }
  
  // MARK: Test data
  
  private let publicKey: String =
  """
  -----BEGIN PGP PUBLIC KEY BLOCK-----

  mQENBGCGqHcBCADMbVyAkL2msB1HZyXDdca2vSpLB2YWgzwvPQF5whOxHTmeBY44
  tBttqB/jKXVlKFMuQJvkh2eIRAMzJHFK1Xd2MQHGGlbn9CYcBIdEUGhUh6/8ZGc7
  PkmxWnI0gaxsYENry8cKHbLHGA0hN+g8eHFbDzrbCEez8J1QSvykDr7TWG8sBdGa
  HWjRFHo8rQerLOlHoGWff/9KgkZN4mO7OBavITJVKA8g+bC9G0rt4vPzx60Uw1IF
  /9jeHSYdySM6rMMR73gW+EohkTmxX7gpSwdagP6orOVvZ7kOh8K8Jv48OSIV7LEY
  CTM5wFslypIWrCjMtebPaYm4DEI4MhugY/wtABEBAAG0H2pvaG5Ac21pdGguY29t
  IDxqb2huQHNtaXRoLmNvbT6JAVQEEwEIAD4WIQQqSELPFT8AP1ZcIsAa6zXuwiLS
  vAUCYIaodwIbAwUJA8JnAAULCQgHAgYVCgkICwIEFgIDAQIeAQIXgAAKCRAa6zXu
  wiLSvGyAB/41zXhopDvaBUu1aG0YlLXpEnaIrZjQuM+bPD0FL2ihrBZfCafh09B7
  YoqDwvOMywK5OsiQja95pWQTfwjsLibbGwlqCjmBGKn8l9DMMCW+oxFgacFaCarc
  cVGXi6LPvuzurKo3kR4r8FUyNC5BUE/RyukxIzgU5Pc2F61OPERkNOYLarreKCbf
  l6m+0qpQMhVMs3ycu6itRpf9FSrddIVNFQ2CgHP4chv9m2xCpiGZKBcnQJPiV2ZX
  DwynQF+e79BXyvXp9KwiHAa+SUJMLfdRJCzkZlhqTbJKiTEa0krBqxkhfVpu84Ui
  mLLF+UC9sWHGCkOfRgYi36jgTVeZ/qG7uQENBGCGqHcBCAC0JDyMuhcyJ+K7aqMp
  wDyxMnChtOGVaDNKjrlWD3ymRGmKCf+fbq4HQg+Mplp0K20PCswnqLzhv5qGT35l
  9G5Ll2rhtiGQQAn6o31TXwdtgmw1rqpWjFgnyWnKsYaE/gYbR0AKoqBIWm7JCBQ4
  qLdg160A4e1nf1J9P15sQSblEDlO6ccyT8vLcEHfpP1ocoUhP+YNm89NLvaxJhJP
  +J8fdvxheTAPexrvzGkH36xPzQcJSEsscULYY3ROIwoFDnDgNYykWdWGTq6Mw3w2
  Y7l1RtfaRL8DF5QwFRkpt5Y7AsC2loPTnF6KFYv3MMOkhMEYnWB0NyPSMUwDdj48
  LsfvABEBAAGJATwEGAEIACYWIQQqSELPFT8AP1ZcIsAa6zXuwiLSvAUCYIaodwIb
  DAUJA8JnAAAKCRAa6zXuwiLSvKsBB/0X2xa7Tkuw4lwPzK1fPWD/CUyaYGWHxLBF
  2kUvpD7fA2mcBDPq3RGYsqCiAXroZ0zBVEWXIGOn/dBxWPWTu6Sp3SKM54h/7Y0E
  fMuEJRRgmQt2KJ4G98hkenb80jbKCdvUgAkKdAKenuCatV1CrS3Yc7UXCEskDPYZ
  65De0U904McF4xfjetCqdtMaLOc3Zzw6fOE6XWggdTkfbQtq05AGTHaQozGoLFfo
  c9Oedmq/Xf3RPkEmx1kQGL7bxnmozu2aZ8aqUAbvUE2+h2J1khBtEM94Dkx6Umi2
  yRtBvQVl4QPn1cfUaW8vjiS+leLvnUmefIxCUjNEMwWD3kHNPhXy
  =0jTj
  -----END PGP PUBLIC KEY BLOCK-----
  """
  
  private let privateKey: String =
  """
  -----BEGIN PGP PRIVATE KEY BLOCK-----
  
  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
  =6KHK
  -----END PGP PRIVATE KEY BLOCK-----
  """
  
  // 'Passbolt\n'
  private let signedCiphertext: String =
  """
  -----BEGIN PGP MESSAGE-----

  hQEMAz7j+YvkYQexAQf/T33IcS326VZ2JFbPFig/mDVS0fuSz+rH8CliXq3BHq87
  Uhbp1fXtyMaZrJJcUhwe9o658xz/mWGkuQ6n/P4JtCjHjPkpkiC19OxQSm/9SshW
  j3gGxG/vKHygkxmPNjHQcgXI2P2OFKMCqmjs9MqH5AI0ptT0OFR7wqbW7GvQYoBQ
  O4Pdb20QCzuixvIO+STupJL/w3+LLIzzu+VAXxMne5uaM5G26ybYwx5ozIz3gLNi
  Q3Cz1hqB+LVdqekDFGnIZVlnZQWBmOHm7V0VEEBzZje7Gc3+sQHd2tnWPkg8y7st
  p6ad5Q4GWvAUHbcWJS7BhIgKxjDSgT3IB3sevVNnzdLAyQG9TfoERDclz4FBlHyf
  5ublY0/oJTJjsX/+JePV/n2HML4w9XWgmDEyUtVfidpBuVXAbRGXGkd3VdBM89Jv
  mCgFMuL6K/2hY7EFO6wubmqKF3k/3M5BDwPglcuBHeL8xCS+MisBgbGno1Gvp52V
  wjHfnt0myLipCto2nsUcL2F2p0G37HGW5gGvNFBsTxgWZWW8MRBk7oEb1OAqnye7
  gIJDWqZrSD0oifjLbLwq8lOWaPK2rqsQcOCeJfUOR8Zlkh9SV4t5TLvmnbGc0/92
  NHIUs+3h5vIcBGDimKt1P/3g6SZYVN5Oc2VXhxMAzeOWTvtm9RfuxWUi2I58gSNP
  hMQ+GhhyYUui7GwslB44kBPi99RKhjQN6l4tgkoRskUwoX4smFKXFjd9JSrhF47c
  zE9OIJaqch58GadaSmHg0s5G97pqMzqYNFffTlYRBwtNDDDvDAVes7V0G0f2b3dJ
  n0uijJmPbxTGMcmclNbhE9xZ84VSLFZkVeLZghH0/G1XeKVw9AwZ38Pp/w==
  =ynnI
  -----END PGP MESSAGE-----
  """
  
  private let signedMessage: String =
  """
  -----BEGIN PGP SIGNED MESSAGE-----
  Hash: SHA256

  Passbolt
  -----BEGIN PGP SIGNATURE-----

  iQEzBAEBCAAdFiEEKkhCzxU/AD9WXCLAGus17sIi0rwFAmCI9LMACgkQGus17sIi
  0ryz+QgAraTeA93+mXvFuDVutL+P2Q1l675WS6YxBSFeeAP+klF8f39kTEM/mDz6
  klxx1tZPybNnuW6rX9LXlhS6pGmRmjX/Q/tHfqIMbwQ9g36CIWpR3R/czCKSla+t
  vPVc8dhvFdWn6GuCHsalLVsBvalk/dFvJ0qJzKN9OPnxmOrVjvxfRfvO/0hsKeqw
  XofytEAgnQBrWxRj5cHCEPFM6QcgwSHJUXSAy8YEA7pHUsadf39FR+t4HFX8hZyo
  k1RFLy2XNuMD6I6b2k2fmr2Zn2PZJWUOUeOA4Quqq+a1azmzrkf7wDF9gft+Tu9k
  ocY/q6eErw7jbTjScIzZOnnjsLYYOg==
  =iL52
  -----END PGP SIGNATURE-----
  """
}
