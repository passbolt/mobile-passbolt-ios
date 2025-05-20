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

import TestExtensions
import XCTest

@testable import PassboltResources

final class MetadataKeysServiceTests: LoadableFeatureTestCase<MetadataKeysService> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltMetadataKeysService()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    // pass-through implementations
    patch(
      \SessionCryptography.decryptMessage,
      with: { input, _ in .init(input) }
    )
    patch(
      \PGP.decrypt,
      with: { input, _, _ in .success(input) }
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \SessionCryptography.decryptSessionKey,
      with: always("")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(.failure(PGPIssue.error(underlyingError: MockError().asTheError())))
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([])
    )
  }

  func testGivenValidKey_MessageShouldBeDecrypted() async throws {
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([metadataKey])
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let decrypted: Data? = try await testedInstance.decrypt(
      message: "TestMessage",
      resourceId: .mock_1,
      withSharedKeyId: metadataKey.id
    )
    XCTAssertNotNil(decrypted)
  }

  func testGivenInvalidKey_MessageShouldNotBeDecrypted() async throws {
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let decrypted: Data? = try await testedInstance.decrypt(
      message: "TestMessage",
      resourceId: .mock_1,
      withSharedKeyId: metadataKey.id
    )
    XCTAssertNil(decrypted)
  }

  func testMessageEncryptedWithUserKey_shouldBeDecrypted() async throws {
    let testedInstance: MetadataKeysService = try self.testedInstance()
    let decrypted: Data? = try await testedInstance.decrypt("TestMessage", .resource(.mock_1), .userKey)
    XCTAssertNotNil(decrypted)
  }

  func testTooLongPublicKey_shouldThrowError() throws {
    let metadataKey: MetadataKeyDTO = .mock(armoredKey: .init(stringLiteral: String(repeating: "a", count: 100001)))
    verifyIfTriggersValidationError(
      try metadataKey.validate(withPrivateKeys: []),
      validationRule: MetadataKeyDTO.ValidationRule.publicKeyTooLong
    )
  }

  func testTooLongPrivateKey_shouldThrowError() throws {
    let privateKey: MetadataDecryptedPrivateKey = .mock(
      armoredKey: .init(stringLiteral: String(repeating: "a", count: 100001))
    )
    let metadataKey: MetadataKeyDTO = .mock()
    verifyIfTriggersValidationError(
      try metadataKey.validate(withPrivateKeys: [privateKey]),
      validationRule: MetadataKeyDTO.ValidationRule.privateKeyTooLong
    )
  }

  func testMismatchingFingerPrint_shouldThrowError() throws {
    let privateKey: MetadataDecryptedPrivateKey = .mock(fingerPrint: "different")
    let metadataKey: MetadataKeyDTO = .mock()
    verifyIfTriggersValidationError(
      try metadataKey.validate(withPrivateKeys: [privateKey]),
      validationRule: MetadataKeyDTO.ValidationRule.fingerprintsMismatch
    )
  }

  func testMismatchingObjectType_shouldThrowError() throws {
    let privateKey: MetadataDecryptedPrivateKey = .mock(objectType: .resourceMetadata)
    let metadataKey: MetadataKeyDTO = .mock(fingerPrint: "fingerprint")
    verifyIfTriggersValidationError(
      try metadataKey.validate(withPrivateKeys: [privateKey]),
      validationRule: MetadataKeyDTO.ValidationRule.invalidObjectType
    )
  }

  func testIfSessionKeyExists_shouldBeUsedToDecryptMessage() async throws {
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([.mock_1])
    )

    let usedSessionKeyExpectation: XCTestExpectation = .init(
      description: "Session key should be used to decrypt message."
    )

    patch(
      \PGP.decryptWithSessionKey,
      with: { input, sessionKey in
        usedSessionKeyExpectation.fulfill()
        return input
      }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let result: Data? = try await testedInstance.decrypt("message", .resource(.mock_1), .userKey)
    await fulfillment(of: [usedSessionKeyExpectation], timeout: 1.0)
    XCTAssertEqual(String(data: result!, encoding: .utf8), "message", "Message should be decrypted.")
  }

  func testInvalidSessionKey_shouldFallbackToStandardDecryptionMethods() async throws {
    let decryptedUsingUserKeyExpectation: XCTestExpectation = .init(
      description: "Message should be decrypted using user key."
    )
    let attempetedToDecryptUsingSessionKeyExpectation: XCTestExpectation = .init(
      description: "Message should be attempted to decrypt using session key."
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([.mock_1])
    )
    patch(
      \PGP.decryptWithSessionKey,
      with: { _, _ in
        attempetedToDecryptUsingSessionKeyExpectation.fulfill()
        throw MockError()
      }
    )

    patch(
      \SessionCryptography.decryptMessage,
      with: { input, _ in
        decryptedUsingUserKeyExpectation.fulfill()
        return .init(input)
      }
    )
    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let result: Data? = try await testedInstance.decrypt("message", .resource(.mock_1), .userKey)
    XCTAssertEqual(String(data: result!, encoding: .utf8), "message", "Message should be decrypted.")

    await fulfillment(
      of: [decryptedUsingUserKeyExpectation, attempetedToDecryptUsingSessionKeyExpectation],
      timeout: 1.0
    )
  }

  func testMissingKeys_shouldBeSavedAfterBeingDecrypted() async throws {
    let savedSessionKeysExpectation: XCTestExpectation = .init(description: "Session keys should be saved.")
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \SessionCryptography.decryptSessionKey,
      with: always("sessionKey")
    )

    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([
        .mock_1
      ])
    )

    patch(
      \MetadataSessionKeysUpdateNetworkOperation.execute,
      with: { input async throws -> EncryptedSessionKeysCache in
        savedSessionKeysExpectation.fulfill()
        XCTAssert(input.data.isEmpty == false, "Session key should be saved.")
        return .mock_1
      }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    _ = try await testedInstance.decrypt("message", .resource(.mock_1), .userKey)
    try await testedInstance.sendSessionKeys()
    await fulfillment(of: [savedSessionKeysExpectation], timeout: 1.0)
  }

  func testGivenMessage_whenSharingRequested_shouldBeEncryptedWithValidKey() async throws {
    let message: String = "message"
    let encryptedMessage: ArmoredPGPMessage = .init(rawValue: "encryptedMessage")
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([metadataKey])
    )

    patch(
      \PGP.encrypt,
      with: { _, _ in .success(encryptedMessage.rawValue) }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let result: (ArmoredPGPMessage, MetadataKeyDTO.ID)? = try await testedInstance.encryptForSharing(message)
    XCTAssertEqual(result?.0, encryptedMessage)
    XCTAssertEqual(result?.1, metadataKey.id)
  }

  func testGivenMessage_whenSharingRequestedAndNoKeysAreExpired_shouldReturnNil() async throws {
    let metadataKey: MetadataKeyDTO = .mock(expired: .now)
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([metadataKey])
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let result: (ArmoredPGPMessage, MetadataKeyDTO.ID)? = try await testedInstance.encryptForSharing("message")
    XCTAssertNil(result)
  }

  func testSendingSessionKeys_whenReceivingHTTPConflictStatus_shouldRefreshKeysAndRetry() async throws {
    let sendSessionKeysExpectation: XCTestExpectation = .init(description: "Session keys should be sent.")
    let refreshKeysExpectation: XCTestExpectation = .init(description: "Keys should be refreshed.")
    sendSessionKeysExpectation.expectedFulfillmentCount = 2
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: { () async throws -> [EncryptedSessionKeyBundle] in
        refreshKeysExpectation.fulfill()
        return []
      }
    )
    patch(
      \MetadataSessionKeysUpdateNetworkOperation.execute,
      with: {
        input async throws -> EncryptedSessionKeysCache in
        sendSessionKeysExpectation.fulfill()
        throw HTTPConflict.error(
          request: .init(),
          response: .init(
            url: .test,
            statusCode: 409,
            headers: [:],
            body: Data()
          )
        )
      }
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always([.mock_1])
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    asyncTestThrows(
      HTTPConflict.self,
      test: {
        try await testedInstance.sendSessionKeys()
      }
    )

    await fulfillment(of: [sendSessionKeysExpectation, refreshKeysExpectation], timeout: 1.0)
  }

  func testMetadataPinnedKeyValidation_whenThereIsNoKeyOnServer_andNoKeyInLocalStorage_shouldPass() async throws {
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(nil)
    )
    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertValid(
      try await testedInstance.validatePinnedKey(),
      "Validation should pass when there is no key on server and no key in local storage."
    )
  }

  func testMetadataPinnedKeyValidation_whenThereIsNoKeyOnServer_andKeyInLocalStorageExists_shouldFail() async throws {
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(MetadataPinnedKeyMock.mock.data)
    )
    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertInvalid(
      try await testedInstance.validatePinnedKey(),
      expectedFailure: .deleted,
      "Validation should fail when there is no key on server and key in local storage exists."
    )
  }

  func testPinnedKeyValidation_whenServerKeyIsSignedByUserAndNoKeyInLocalStorage_shouldPass() async throws {
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_1
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(nil)
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: .mock_admin, publicKey: "public key")])
    )
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private key")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(
        .success(
          .init(
            content: MetadataKeyDTO.MetadataPrivateKey
              .encryptedData(
                fingerprint: "fingerprint",
                armoredKey: "armored_key"
              )
              .stringValue!,
            signature: .init(
              signature: "signature",
              createdAt: .now,
              fingerprint: "signature fingerprint",
              keyID: "signature key id"
            )
          )
        )
      )
    )

    let savedPinnedKeyExpectation: XCTestExpectation = .init(description: "Pinned key should be saved.")
    patch(
      \MetadataKeyDataStore.storePinnedMetadataKey,
      with: { _, _ throws -> Void in
        savedPinnedKeyExpectation.fulfill()
      }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()

    await assertValid(
      try await testedInstance.validatePinnedKey(),
      """
      Validation should pass when there is key on server 
      and key in local storage does not exist and key is signed by user.
      """
    )

    await fulfillment(of: [savedPinnedKeyExpectation], timeout: 1.0)
  }

  func testPinnedKeyValidation_whenKeyOnServerAndLocalStorageExists_andKeyFingerPrintAndModificationDateMatches()
    async throws
  {
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_admin
    )
    let localKey: MetadataPinnedKeyMock = .init(
      fingerPrint: Fingerprint("fingerprint"),
      modified: modificationDate
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(localKey.data)
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertValid(
      try await testedInstance.validatePinnedKey(),
      """
      Validation should pass when there is key on server 
      and key in local storage exists and key fingerprint and modification date matches.
      """
    )
  }

  func testMetadataPinnedKeyValidation_whenKeyDataMismatches_andItIsNotSignedByUser_shouldFail() async throws {
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_admin
    )
    let localKey: MetadataPinnedKeyMock = .init(
      fingerPrint: Fingerprint("fingerprint"),
      modified: modificationDate.addingTimeInterval(-120)
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(localKey.data)
    )
    patch(
      \UserDetailsFetchDatabaseOperation.execute,
      with: always(.mock_1)
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertInvalid(
      try await testedInstance.validatePinnedKey(),
      expectedFailure: .changed("mock 1", "fingerprint"),
      """
      Validation should fail if keys fingerprint or modification date mismatches
      and key is not signed by user.
      """
    )
  }

  func testMetadataPinnedKeyValidation_whenKeyDataMismatches_andItIsSignedByUserButItIsOlder_shouldFail() async throws {
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_admin
    )
    let localKey: MetadataPinnedKeyMock = .init(
      fingerPrint: Fingerprint("fingerprint"),
      modified: modificationDate.addingTimeInterval(120)
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(localKey.data)
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: .mock_admin, publicKey: "public key")])
    )
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private key")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(
        .success(
          .init(
            content: MetadataKeyDTO.MetadataPrivateKey
              .encryptedData(
                fingerprint: "fingerprint",
                armoredKey: "armored_key"
              )
              .stringValue!,
            signature: .init(
              signature: "signature",
              createdAt: .now,
              fingerprint: "signature fingerprint",
              keyID: "signature key id"
            )
          )
        )
      )
    )

    patch(
      \UserDetailsFetchDatabaseOperation.execute,
      with: always(.mock_1)
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertInvalid(
      try await testedInstance.validatePinnedKey(),
      expectedFailure: .changed("mock 1", "fingerprint"),
      """
      Validation should fail if keys fingerprint or modification date mismatches,
      key is signed by user but server side key is older.
      """
    )
  }

  func testMetadataPinnedKeyValidation_whenKeyDataMismatches_andItIsSignedByUserButItIsNewer_shouldPassAndStoreNewKey()
    async throws
  {
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_admin
    )
    let localKey: MetadataPinnedKeyMock = .init(
      fingerPrint: Fingerprint("fingerprint"),
      modified: modificationDate.addingTimeInterval(-120)
    )
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \MetadataKeyDataStore.loadPinnedMetadataKey,
      with: always(localKey.data)
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: .mock_admin, publicKey: "public key")])
    )
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private key")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(
        .success(
          .init(
            content: MetadataKeyDTO.MetadataPrivateKey
              .encryptedData(
                fingerprint: "fingerprint",
                armoredKey: "armored_key"
              )
              .stringValue!,
            signature: .init(
              signature: "signature",
              createdAt: .now,
              fingerprint: "signature fingerprint",
              keyID: "signature key id"
            )
          )
        )
      )
    )

    let savedPinnedKeyExpectation: XCTestExpectation = .init(description: "Pinned key should be saved.")
    patch(
      \MetadataKeyDataStore.storePinnedMetadataKey,
      with: { _, _ throws -> Void in
        savedPinnedKeyExpectation.fulfill()
      }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    await assertValid(
      try await testedInstance.validatePinnedKey(),
      """
      Validation should pass if keys fingerprint or modification date mismatches,
      key is signed by user and server side key is newer.
      """
    )
    await fulfillment(of: [savedPinnedKeyExpectation], timeout: 1.0)
  }

  func testTrustingKey_withoutActiveKey_shouldDoNothig() async throws {
    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.trustCurrentKey()
    // no error should be thrown, no mock should be needed
  }

  func testTrustingKey_shouldStore_signKey_andSendToServer() async throws {
    let fetchKeyExpectation: XCTestExpectation = .init(description: "Key should be fetched.")
    fetchKeyExpectation.expectedFulfillmentCount = 2  // should be fetched on initialization and after success
    let modificationDate: Date = .now
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: modificationDate,
      modifiedBy: .mock_admin
    )

    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: { input async throws -> [MetadataKeyDTO] in
        fetchKeyExpectation.fulfill()
        return [serverKey]
      }
    )
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private key")
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: .mock_admin, publicKey: "public key")])
    )
    patch(
      \PGP.encryptAndSign,
      with: always(.success("signed message"))
    )
    patch(
      \MetadataUpdatePrivateKeyNetworkOperation.execute,
      with: always(.init(userId: .mock_1, data: "", createdBy: nil, modifiedBy: nil))
    )

    let storeKeyExpectation: XCTestExpectation = .init(description: "Key should be stored.")
    patch(
      \MetadataKeyDataStore.storePinnedMetadataKey,
      with: { _, _ throws -> Void in
        storeKeyExpectation.fulfill()
      }
    )
    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()

    try await testedInstance.trustCurrentKey()

    await fulfillment(
      of: [storeKeyExpectation, fetchKeyExpectation],
      timeout: 1.0
    )
  }

  func testTrustingKey_ifAlreadySigned_shouldNotSignAndSendToServer() async throws {
    let serverKey: MetadataKeyDTO = .mock(
      fingerPrint: "fingerprint",
      modified: .now,
      modifiedBy: .mock_admin
    )

    patch(
      \MetadataKeysFetchNetworkOperation.execute,
      with: always([serverKey])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: .mock_admin, publicKey: "public key")])
    )
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private key")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(
        .success(
          .init(
            content:
              """
              {
                "fingerprint": "fingerprint",
                "armored_key": "",
                "object_type": "\(MetadataObjectType.privateKeyMetadata.rawValue)"
              }
              """,
            signature: .init(signature: "", createdAt: .now, fingerprint: "signature", keyID: "key id")
          )
        )
      )
    )
    let storeKeyExpectation: XCTestExpectation = .init(description: "Key should be stored.")
    patch(
      \MetadataKeyDataStore.storePinnedMetadataKey,
      with: { _, _ throws -> Void in
        storeKeyExpectation.fulfill()
      }
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()

    try await testedInstance.trustCurrentKey()
    await fulfillment(of: [storeKeyExpectation], timeout: 1.0)
  }
}

private struct MetadataPinnedKeyMock {
  let fingerPrint: Fingerprint
  let modified: Date

  var data: JSON {
    [
      "fingerprint": .string(fingerPrint.rawValue),
      "modified": .float(modified.timeIntervalSince1970),
    ]
  }

  init(fingerPrint: Fingerprint, modified: Date) {
    self.fingerPrint = fingerPrint
    self.modified = modified
  }

  static var mock: Self {
    .init(
      fingerPrint: Fingerprint("fingerprint"),
      modified: .now
    )
  }

}

extension MetadataKeyDTO {
  fileprivate static var mock: Self {
    let id: MetadataKeyDTO.ID = .init()
    let privateKeyData: JSON = [
      "fingerprint": .string("fingerprint"),
      "armored_key": "",
      "object_type": .string(MetadataObjectType.privateKeyMetadata.rawValue),
    ]

    let privateKey: MetadataPrivateKey = .mock(id: id, userId: .init(), encryptedData: privateKeyData)
    return .mock(id: id, fingerPrint: "fingerprint", armoredKey: .mock_ada, privateKeys: [privateKey])
  }

  fileprivate static func mock(
    id: MetadataKeyDTO.ID = .init(),
    fingerPrint: Fingerprint = "",
    armoredKey: ArmoredPGPPublicKey = .mock_ada,
    expired: Date? = nil,
    deleted: Date? = nil,
    modified: Date? = nil,
    modifiedBy: User.ID? = nil,
    privateKeys: [MetadataKeyDTO.MetadataPrivateKey]? = nil
  ) -> Self {
    .init(
      id: id,
      fingerprint: fingerPrint,
      created: .now,
      modified: modified ?? .now,
      modifiedBy: modifiedBy,
      deleted: deleted,
      expired: expired,
      armoredKey: armoredKey,
      privateKeys: privateKeys ?? [
        .init(
          id: id,
          userId: .init(),
          encryptedData:
            MetadataPrivateKey.encryptedData(
              fingerprint: fingerPrint,
              armoredKey: ""
            )
            .stringValue!
        )
      ]
    )
  }
}

extension MetadataDecryptedPrivateKey {
  fileprivate static func mock(
    fingerPrint: String = "fingerprint",
    armoredKey: ArmoredPGPPrivateKey = "",
    objectType: MetadataObjectType = .privateKeyMetadata
  ) -> Self {
    .init(
      fingerprint: fingerPrint,
      armoredKey: armoredKey,
      objectType: objectType
    )
  }
}

extension MetadataKeyDTO.MetadataPrivateKey {
  fileprivate static func mock(
    id: MetadataKeyDTO.ID = .init(),
    userId: Tagged<PassboltID, Self> = .init(),
    encryptedData: JSON = .null
  ) -> Self {
    .init(id: id, userId: userId, encryptedData: encryptedData.stringValue!)
  }

  fileprivate static func encryptedData(fingerprint: Fingerprint, armoredKey: String) -> JSON {
    [
      "fingerprint": .string(fingerprint.rawValue),
      "armored_key": .string(armoredKey),
      "object_type": .string(MetadataObjectType.privateKeyMetadata.rawValue),
    ]
  }
}

private struct MockError: Error {}

extension MetadataKeysServiceTests {

  fileprivate typealias KeyValidationResult = MetadataKeysService.KeyValidationResult

  fileprivate func assertValid(
    _ expression: @autoclosure () async throws -> KeyValidationResult,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    do {
      let result: KeyValidationResult = try await expression()
      XCTAssertTrue(result == .valid, message(), file: file, line: line)
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  fileprivate func assertInvalid(
    _ expression: @autoclosure () async throws -> KeyValidationResult,
    expectedFailure: KeyValidationResult.FailureReason,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
  ) async {
    do {
      let result: KeyValidationResult = try await expression()
      XCTAssertTrue(result == .invalid(expectedFailure), message(), file: file, line: line)
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}
