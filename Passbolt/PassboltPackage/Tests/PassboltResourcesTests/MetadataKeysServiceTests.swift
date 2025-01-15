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
  }

  func testGivenValidKey_MessageShouldBeDecrypted() async throws {
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
       with: always([metadataKey])
    )
    
    let testedInstance = try self.testedInstance()
    try await testedInstance.initialize()
    let decrypted = try await testedInstance.decrypt(message: "TestMessage", withKeyId: metadataKey.id)
    XCTAssertNotNil(decrypted)
  }
  
  func testGivenInvalidKey_MessageShouldNotBeDecrypted() async throws {
    let metadataKey = MetadataKeyDTO.mock
    patch(
      \MetadataKeysFetchNetworkOperation.execute,
       with: always([])
    )
    
    let testedInstance = try self.testedInstance()
    try await testedInstance.initialize()
    let decrypted = try await testedInstance.decrypt(message: "TestMessage", withKeyId: metadataKey.id)
    XCTAssertNil(decrypted)
  }
  
  func testTooLongPublicKey_shouldThrowError() throws {
    let metadataKey = MetadataKeyDTO.mock(armoredKey: .init(stringLiteral: String(repeating: "a", count: 100001)))
    verifyIfTriggersValidationError(try metadataKey.validate(withPrivateKeys: []), validationRule: MetadataKeyDTO.ValidationRule.publicKeyTooLong)
  }
  
  func testTooLongPrivateKey_shouldThrowError() throws {
    let privateKey = MetadataDecryptedPrivateKey.mock(armoredKey: .init(stringLiteral: String(repeating: "a", count: 100001)))
    let metadataKey = MetadataKeyDTO.mock()
    verifyIfTriggersValidationError(try metadataKey.validate(withPrivateKeys: [privateKey]), validationRule: MetadataKeyDTO.ValidationRule.privateKeyTooLong)
  }
  
  func testMismatchingFingerPrint_shouldThrowError() throws {
    let privateKey = MetadataDecryptedPrivateKey.mock(fingerPrint: "different")
    let metadataKey = MetadataKeyDTO.mock()
    verifyIfTriggersValidationError(try metadataKey.validate(withPrivateKeys: [privateKey]), validationRule: MetadataKeyDTO.ValidationRule.fingerprintsMismatch)
  }
}

extension MetadataKeyDTO {
  fileprivate static var mock: Self {
    let id = MetadataKeyDTO.ID()
    let privateKeyData: JSON = [
      "fingerprint": .string("fingerprint"),
      "armored_key": ""
    ]
    
    let privateKey: MetadataPrivateKey = .mock(id: id, userId: .init(), encryptedData: privateKeyData)
    return .mock(id: id, fingerPrint: "fingerprint", armoredKey: .mock_ada, privateKeys: [privateKey])
  }
  
  fileprivate static func mock(
    id: MetadataKeyDTO.ID = .init(),
    fingerPrint: String = "",
    armoredKey: ArmoredPGPPublicKey = .mock_ada,
    privateKeys: [MetadataKeyDTO.MetadataPrivateKey]? = nil
  ) -> Self {
    
    return .init(
        id: id,
        fingerprint: fingerPrint,
        created: .now,
        modified: .now,
        deleted: nil,
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
  fileprivate static func mock(fingerPrint: String = "fingerprint", armoredKey: ArmoredPGPPrivateKey = "") -> Self {
    .init(fingerprint: fingerPrint, armoredKey: armoredKey)
  }
}

extension MetadataKeyDTO.MetadataPrivateKey {
  fileprivate static func mock(id: MetadataKeyDTO.ID = .init(), userId: Tagged<PassboltID, Self> = .init(), encryptedData: JSON = .null) -> Self {
    .init(id: id, userId: userId, encryptedData: encryptedData.stringValue!)
  }
  
  fileprivate static func encryptedData(fingerprint: String, armoredKey: String) -> JSON {
    [
      "fingerprint": .string(fingerprint),
      "armored_key": .string(armoredKey)
    ]
  }
}
