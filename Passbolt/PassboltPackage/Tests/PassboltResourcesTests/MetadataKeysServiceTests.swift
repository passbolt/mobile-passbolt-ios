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

import XCTest
import TestExtensions

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
  }

  func testGivenValidKey_MessageShouldBeDecrypted() async throws {
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
       with: always([metadataKey])
    )

    let testedInstance: MetadataKeysService = try self.testedInstance()
    try await testedInstance.initialize()
    let decrypted: Data? = try await testedInstance.decrypt(message: "TestMessage", resourceId: .mock_1, withSharedKeyId: metadataKey.id)
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
    let decrypted: Data? = try await testedInstance.decrypt(message: "TestMessage", resourceId: .mock_1, withSharedKeyId: metadataKey.id)
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
    let privateKey: MetadataDecryptedPrivateKey = .mock(armoredKey: .init(stringLiteral: String(repeating: "a", count: 100001)))
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
    
    let usedSessionKeyExpectation: XCTestExpectation = .init(description: "Session key should be used to decrypt message.")
    
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
    let decryptedUsingUserKeyExpectation: XCTestExpectation = .init(description: "Message should be decrypted using user key.")
    let attempetedToDecryptUsingSessionKeyExpectation: XCTestExpectation = .init(description: "Message should be attempted to decrypt using session key.")
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
    
    await fulfillment(of: [decryptedUsingUserKeyExpectation, attempetedToDecryptUsingSessionKeyExpectation], timeout: 1.0)
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
      \MetadataSessionKeysCreateNetworkOperation.execute,
       with:
        { input async throws -> Void in
         savedSessionKeysExpectation.fulfill()
         XCTAssert(input.data.isEmpty == false, "Session key should be saved.")
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
}

extension MetadataKeyDTO {
  fileprivate static var mock: Self {
    let id: MetadataKeyDTO.ID = .init()
    let privateKeyData: JSON = [
      "fingerprint": .string("fingerprint"),
      "armored_key": "",
      "object_type": .string(MetadataObjectType.privateKeyMetadata.rawValue)
    ]

    let privateKey: MetadataPrivateKey = .mock(id: id, userId: .init(), encryptedData: privateKeyData)
    return .mock(id: id, fingerPrint: "fingerprint", armoredKey: .mock_ada, privateKeys: [privateKey])
  }

  fileprivate static func mock(
    id: MetadataKeyDTO.ID = .init(),
    fingerPrint: String = "",
    armoredKey: ArmoredPGPPublicKey = .mock_ada,
    expired: Date? = nil,
    deleted: Date? = nil,
    privateKeys: [MetadataKeyDTO.MetadataPrivateKey]? = nil
  ) -> Self {

    return .init(
        id: id,
        fingerprint: fingerPrint,
        created: .now,
        modified: .now,
        deleted: deleted,
        expired: expired,
        armoredKey: armoredKey,
        privateKeys: privateKeys ?? [
          .init(
            id: id,
            userId: .init(),
            encryptedData: MetadataPrivateKey.encryptedData(
              fingerprint: fingerPrint,
              armoredKey: ""
            ).stringValue!
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
    .init(fingerprint: fingerPrint, armoredKey: armoredKey, objectType: objectType)
  }
}

extension MetadataKeyDTO.MetadataPrivateKey {
  fileprivate static func mock(id: MetadataKeyDTO.ID = .init(), userId: Tagged<PassboltID, Self> = .init(), encryptedData: JSON = .null) -> Self {
    .init(id: id, userId: userId, encryptedData: encryptedData.stringValue!)
  }

  fileprivate static func encryptedData(fingerprint: String, armoredKey: String) -> JSON {
    [
      "fingerprint": .string(fingerprint),
      "armored_key": .string(armoredKey),
      "object_type": .string(MetadataObjectType.privateKeyMetadata.rawValue)
    ]
  }
}

private struct MockError: Error {}
