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

import Crypto
import TestExtensions

@testable import PassboltAccounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountsStoreTests: LoadableFeatureTestCase<Accounts> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltAccounts
  }

  override func prepare() throws {
    use(Session.placeholder)
    patch(
      \Session.close,
      with: always(Void())
    )
  }

  func test_storedAccounts_returnsAccountsFromAccountsDataStore() async throws {
    patch(
      \AccountsDataStore.loadAccounts,
      with: always([.mock_ada])
    )

    let accounts: Accounts = try await testedInstance()

    let result: Array<Account> = accounts.storedAccounts()

    XCTAssertEqual(result, [Account.mock_ada])
  }

  func test_verifyAccountsDataIntegrity_verifiesAccountsDataStore() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \AccountsDataStore.verifyDataIntegrity,
      with: {
        uncheckedSendableResult.variable = Void()
      }
    )
    patch(
      \AccountsDataStore.loadAccounts,
      with: always([.mock_ada])
    )

    let accounts: Accounts = try await testedInstance()

    _ = try? accounts.verifyDataIntegrity()

    XCTAssertNotNil(result)
  }

  func test_addAccount_storesDataInAccountsDataStore() async throws {
    let expectedResult: AccountWithProfile = .init(
      localID: .init(rawValue: UUID.test.uuidString),
      userID: .init(rawValue: UUID.test.uuidString),
      domain: AccountWithProfile.mock_ada.domain,
      label: AccountWithProfile.mock_ada.label,
      username: AccountWithProfile.mock_ada.username,
      firstName: AccountWithProfile.mock_ada.firstName,
      lastName: AccountWithProfile.mock_ada.lastName,
      avatarImageURL: AccountWithProfile.mock_ada.avatarImageURL,
      fingerprint: AccountWithProfile.mock_ada.fingerprint
    )
    var result: (account: Account, details: AccountProfile, armoredKey: ArmoredPGPPrivateKey)?
    let uncheckedSendableResult:
      UncheckedSendable<(account: Account, details: AccountProfile, armoredKey: ArmoredPGPPrivateKey)?> = .init(
        get: { result },
        set: { result = $0 }
      )
    patch(
      \AccountsDataStore.storeAccount,
      with: { account, details, key in
        uncheckedSendableResult.variable = (account, details, key)
      }
    )
    patch(
      \AccountsDataStore.loadAccounts,
      with: always([])
    )
    patch(
      \Session.authorize,
      with: always(Void())
    )
    patch(
      environment: \.uuidGenerator.uuid,
      with: always(.test)
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success)
    )

    let accounts: Accounts = try await testedInstance()

    _ =
      try accounts
      .addAccount(
        .init(
          userID: expectedResult.userID,
          domain: expectedResult.domain,
          username: expectedResult.username,
          firstName: expectedResult.firstName,
          lastName: expectedResult.lastName,
          avatarImageURL: expectedResult.avatarImageURL,
          fingerprint: expectedResult.fingerprint,
          armoredKey: validPrivateKey
        )
      )

    XCTAssertEqual(result?.account, expectedResult.account)
    XCTAssertEqual(result?.details, expectedResult.profile)
    XCTAssertEqual(result?.armoredKey, validPrivateKey)
  }

  func test_addAccount_continuesWithoutStoring_whenAccountAlreadyStored() async throws {
    patch(
      \Session.authorize,
      with: always(Void())
    )
    patch(
      \AccountsDataStore.loadAccounts,
      with: always([.mock_ada])
    )
    patch(
      environment: \.uuidGenerator.uuid,
      with: always(.test)
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success)
    )

    let accounts: Accounts = try await testedInstance()

    var result: Error?
    do {
      _ =
        try accounts
        .addAccount(
          .init(
            userID: AccountWithProfile.mock_ada.userID,
            domain: AccountWithProfile.mock_ada.domain,
            username: AccountWithProfile.mock_ada.username,
            firstName: AccountWithProfile.mock_ada.firstName,
            lastName: AccountWithProfile.mock_ada.lastName,
            avatarImageURL: AccountWithProfile.mock_ada.avatarImageURL,
            fingerprint: AccountWithProfile.mock_ada.fingerprint,
            armoredKey: validPrivateKey
          )
        )
    }
    catch {
      result = error
    }

    XCTAssertNil(result)
  }

  func test_removeAccount_removesDataFromAccountsDataStore() async throws {
    var result: Account.LocalID?
    let uncheckedSendableResult: UncheckedSendable<Account.LocalID?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \AccountsDataStore.deleteAccount,
      with: {
        uncheckedSendableResult.variable = $0
      }
    )
    patch(
      \AccountsDataStore.loadAccounts,
      with: always([.mock_ada])
    )

    let accounts: Accounts = try await testedInstance()

    _ = try? await accounts.removeAccount(Account.mock_ada)

    XCTAssertEqual(result, Account.mock_ada.localID)
  }
}

private let validPassphrase: Passphrase = "SecretPassphrase"

private let validPrivateKey: ArmoredPGPPrivateKey =
  """
  -----BEGIN PGP PRIVATE KEY BLOCK-----

  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
  =6KHK
  -----END PGP PRIVATE KEY BLOCK-----
  """

private let validToken: JWT = try! .from(
  rawValue: """
    eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
    """
)
.get()
