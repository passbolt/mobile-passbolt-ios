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

@testable import PassboltAccounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountsDataStoreTests: LoadableFeatureTestCase<AccountsDataStore> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltAccountsDataStore
  }

  var mockPreferencesStore: Dictionary<Preferences.Key, Any>!
  var mockKeychainStore: Array<(data: Data, query: KeychainQuery)>!

  override func prepare() throws {
    mockKeychainStore = .init()
    patch(
      environment: \.keychain.load,
      with: { [unowned self] query in
        return .success(
          self.mockKeychainStore
            .filter {
              $0.query.key == query.key
                && ($0.query.tag == query.tag
                  || query.tag == nil)
            }
            .map(\.data)
        )
      }
    )
    patch(
      environment: \.keychain.loadMeta,
      with: { [unowned self] query in
        return .success(
          self.mockKeychainStore
            .filter { $0.query.key == query.key && ($0.query.tag == query.tag || query.tag == nil) }
            .map {
              KeychainItemMetadata(
                key: .init(rawValue: $0.query.key.rawValue),
                tag: $0.query.tag.map { .init(rawValue: $0.rawValue) }
              )
            }
        )
      }
    )
    patch(
      environment: \.keychain.save,
      with: { [unowned self] data, query in
        self.mockKeychainStore.removeAll(
          where: {
            $0.query.key == query.key
              && ($0.query.tag == query.tag || query.tag == nil)
          }
        )
        self.mockKeychainStore.append((data: data, query: query))
        return .success
      }
    )
    patch(
      environment: \.keychain.delete,
      with: { [unowned self] query in
        self.mockKeychainStore.removeAll(
          where: {
            $0.query.key == query.key
              && ($0.query.tag == query.tag || query.tag == nil)
          }
        )
        return .success
      }
    )

    mockPreferencesStore = .init()
    patch(
      environment: \.preferences.load,
      with: { [unowned self] key in
        self.mockPreferencesStore[key]
      }
    )
    patch(
      environment: \.preferences.save,
      with: { [unowned self] data, key in
        self.mockPreferencesStore[key] = data
      }
    )

    patch(
      environment: \.files.applicationDataDirectory,
      with: always(.success(URL(string: "file:///test")!))
    )
    patch(
      environment: \.files.contentsOfDirectory,
      with: always(.success([]))
    )
  }

  override func cleanup() throws {
    mockPreferencesStore = nil
    mockKeychainStore = nil
  }

  func test_loadAccounts_loadsItemsStoredInKeychain() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.success([validAccountKeychainData]))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Array<Account> = await dataStore.loadAccounts()

    XCTAssertEqual(result, [.mock_ada])
  }

  func test_loadAccounts_loadsEmptyIfKeychainContainsInvalidItems() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.success([Data([65, 66, 67]), validAccountKeychainData]))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Array<Account> = await dataStore.loadAccounts()

    XCTAssertEqual(result, [])
  }

  func test_loadAccounts_loadsEmptyIfKeychainLoadFails() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.failure(MockIssue.error()))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Array<Account> = await dataStore.loadAccounts()

    XCTAssertEqual(result, [])
  }

  func test_loadLastUsedAccount_loadsStoredLastAccount() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.success([validAccountKeychainData]))
    )
    patch(
      environment: \.preferences.load,
      with: always(Account.mock_ada.localID.rawValue)
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Account? = await dataStore.loadLastUsedAccount()

    XCTAssertEqual(result, Account.mock_ada)
  }

  func test_loadLastUsedAccount_loadsNoneIfKeychainDataIsMissing() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.success([]))
    )
    patch(
      environment: \.preferences.load,
      with: always(Account.mock_ada.localID.rawValue)
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Account? = await dataStore.loadLastUsedAccount()

    XCTAssertNil(result)
  }

  func test_loadLastUsedAccount_loadsNoneIfKeychainLoadFails() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.failure(MockIssue.error()))
    )
    patch(
      environment: \.preferences.load,
      with: always(Account.mock_ada.localID.rawValue)
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Account? = await dataStore.loadLastUsedAccount()

    XCTAssertNil(result)
  }

  func test_loadLastUsedAccount_loadsNoneIfNoAccountIDSaved() async throws {
    patch(
      environment: \.keychain.load,
      with: always(.success([validAccountKeychainData]))
    )
    patch(
      environment: \.preferences.load,
      with: always(nil)
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Account? = await dataStore.loadLastUsedAccount()

    XCTAssertNil(result)
  }

  func test_saveLastUsedAccount_savesAccountID() async throws {
    var result: String?
    patch(
      environment: \.preferences.save,
      with: { value, _ in
        result = value as? String
      }
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    await dataStore.storeLastUsedAccount(Account.mock_ada.localID)

    XCTAssertEqual(
      result,
      Account.mock_ada.localID.rawValue
    )
  }

  func test_storeAccount_savesDataProperly() async throws {
    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.storeAccount(
        Account.mock_ada,
        AccountProfile.mock_ada,
        validPrivateKey
      )
    }

    XCTAssertSuccess(result)
    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      [Account.mock_ada.localID.rawValue]
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      [validAccountProfileKeychainData, validAccountKeychainData, validPrivateKeyKeychainData]
    )
  }

  func test_storeAccount_failsIfKeychainSaveFails() async throws {
    patch(
      environment: \.keychain.save,
      with: always(.failure(MockIssue.error()))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.storeAccount(
        Account.mock_ada,
        AccountProfile.mock_ada,
        validPrivateKey
      )
    }

    XCTAssertFailure(result)
  }

  func test_storeAccount_dataIsNotSavedIfKeychainSaveFails() async throws {
    patch(
      environment: \.keychain.save,
      with: always(.failure(MockIssue.error()))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    _ = try? await dataStore.storeAccount(Account.mock_ada, AccountProfile.mock_ada, validPrivateKey)

    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      []
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }

  func test_deleteAccount_removesAccountData() async throws {
    patch(
      environment: \.files.deleteFile,
      with: always(.success)
    )
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]

    let dataStore: AccountsDataStore = try await testedInstance()

    await dataStore.deleteAccount(Account.mock_ada.localID)

    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      []
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }

  func test_deleteAccount_removesAccountDatabase() async throws {
    var result: URL!
    patch(
      environment: \.files.deleteFile,
      with: { url in
        result = url
        return .success
      }
    )
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]

    let dataStore: AccountsDataStore = try await testedInstance()

    dataStore.deleteAccount(Account.mock_ada.localID)

    XCTAssertEqual(
      result.lastPathComponent,
      "\(Account.mock_ada.localID).sqlite"
    )
  }

  func test_storeServerFingerprint_savesDataProperly() async throws {
    var result: Void?
    patch(
      environment: \.keychain.save,
      with: { _, _ in
        result = Void()
        return .success
      }
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    _ = try? await dataStore.storeServerFingerprint(Account.mock_ada.localID, serverFingerprint)

    XCTAssertNotNil(result)
  }

  func test_storeServerFingerprint_failsIfKeychainSaveFails() async throws {
    patch(
      environment: \.keychain.save,
      with: always(.failure(MockIssue.error()))
    )

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.storeServerFingerprint(Account.mock_ada.localID, serverFingerprint)
    }

    XCTAssertFailure(result)
  }

  func test_verifyDataIntegrity_succeedsWithNoData() async throws {
    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
  }

  func test_verifyDataIntegrity_succeedsWithValidData() async throws {
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]
    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
  }

  func test_verifyDataIntegrity_doesNotModifyValidData() async throws {
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validAccountProfileKeychainData,
        query: .init(
          key: "accountProfile",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]
    let dataStore: AccountsDataStore = try await testedInstance()

    _ = try? await dataStore.verifyDataIntegrity()

    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      [Account.mock_ada.localID.rawValue]
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      [validAccountProfileKeychainData, validAccountKeychainData, validPrivateKeyKeychainData]
    )
  }

  func test_verifyDataIntegrity_removesAccountsData_whenAccountIDIsNotInList() async throws {
    mockPreferencesStore["accountsList"] = []
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]
    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      []
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }

  func test_verifyDataIntegrity_removesAccountsData_whenAccountDataIsNotStored() async throws {
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      )
    ]

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      []
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }

  func test_verifyDataIntegrity_removesAccountsData_whenPrivateKeyIsNotStored() async throws {
    mockPreferencesStore["accountsList"] = [Account.mock_ada.localID.rawValue]
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      )
    ]

    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
    XCTAssertEqual(
      mockPreferencesStore["accountsList"] as? Array<String>,
      []
    )
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }

  func test_verifyDataIntegrity_removesAccountsDatabase_whenAccountIDIsNotInListAndDatabaseFileExists() async throws {
    var result: URL?
    patch(
      environment: \.files.contentsOfDirectory,
      with: always(.success(["\(Account.mock_ada.localID).sqlite"]))
    )
    patch(
      environment: \.files.deleteFile,
      with: { url in
        result = url
        return .success
      }
    )
    mockPreferencesStore["accountsList"] = []
    mockKeychainStore = [
      (
        data: validAccountKeychainData,
        query: .init(
          key: "account",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
      (
        data: validPrivateKeyKeychainData,
        query: .init(
          key: "accountArmoredKey",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      ),
    ]
    let dataStore: AccountsDataStore = try await testedInstance()

    _ = try? await dataStore.verifyDataIntegrity()

    XCTAssertEqual(
      result?.lastPathComponent,
      "\(Account.mock_ada.localID).sqlite"
    )
  }

  func test_verifyDataIntegrity_removesServerFingerprintData_whenAccountIDIsNotInList() async throws {
    mockKeychainStore = [
      (
        data: validServerFingerprint,
        query: .init(
          key: "serverFingerprint",
          tag: .init(rawValue: Account.mock_ada.localID.rawValue),
          requiresBiometrics: false
        )
      )
    ]
    let dataStore: AccountsDataStore = try await testedInstance()

    let result: Result<Void, Error> = await .async {
      try await dataStore.verifyDataIntegrity()
    }

    XCTAssertSuccess(result)
    XCTAssertEqual(
      mockKeychainStore.map(\.data),
      []
    )
  }
}

// keychain wrapper encodes values within own structure putting value under "v" key
private let validAccountKeychainData: Data = try! JSONEncoder().encode(["v": Account.mock_ada])

// keychain wrapper encodes values within own structure putting value under "v" key
private let validAccountProfileKeychainData: Data = try! JSONEncoder().encode(["v": AccountProfile.mock_ada])

private let validPrivateKey: ArmoredPGPPrivateKey =
  """
  -----BEGIN PGP PRIVATE KEY BLOCK-----

  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
  =6KHK
  -----END PGP PRIVATE KEY BLOCK-----
  """

private let serverFingerprint: Fingerprint = .init(rawValue: "E8FE388E385841B382B674ADB02DADCD9565E1B8")

private let validServerFingerprint: Data = try! JSONEncoder().encode(["v": serverFingerprint])
// keychain wrapper encodes values within own structure putting value under "v" key
private let validPrivateKeyKeychainData: Data = try! JSONEncoder().encode(["v": validPrivateKey])
