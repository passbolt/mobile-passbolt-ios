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

import Combine
import Crypto
import Features
import TestExtensions

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSettingsTests: TestCase {

  var accountSession: AccountSession!
  var accountsDataStore: AccountsDataStore!
  var permissions: OSPermissions!
  var passphraseCache: PassphraseCache!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    accountsDataStore = .placeholder
    permissions = .placeholder
    passphraseCache = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    accountsDataStore = nil
    permissions = nil
    passphraseCache = nil
    super.tearDown()
  }

  func test_biometricsEnabledPublisher_publishesProfileValueInitially() {
    accountSession.statePublisher = always(
      CurrentValueSubject<AccountSession.State, Never>(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: Bool!
    feature
      .biometricsEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_biometricsEnabledPublisher_publishesTrue_afterBiometricsStateInProfileChangesToTrue() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    var currentAccount: AccountProfile = validAccountProfile
    accountsDataStore.loadAccountProfile = always(.success(currentAccount))
    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountsDataStore.updatedAccountIDsPublisher = always(updatedAccountIDSubject.eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: Bool!
    feature
      .biometricsEnabledPublisher()
      .dropFirst()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    currentAccount.biometricsEnabled = true
    updatedAccountIDSubject.send(currentAccount.accountID)

    XCTAssertTrue(result)
  }

  func test_biometricsEnabledPublisher_publishesFalse_whenProfileLoadingFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.failure(.testError()))
    accountsDataStore.storeAccountPassphrase = always(.success)
    accountsDataStore.updatedAccountIDsPublisher = always(Just(validAccount.localID).eraseToAnyPublisher())

    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: Bool!
    feature
      .biometricsEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_setBiometricsEnabled_succeedsEnabling_withAllRequirementsFulfilled() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setBiometricsEnabled_succeedsDisabling_withAllRequirementsFulfilled() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.deleteAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setBiometricsEnabled_failsDisabling_withNoSession() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.deleteAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setBiometricsEnabled_failsDisabling_withSessionAuthorizationRequired() {
    accountSession.statePublisher = always(
      Just(.authorizationRequired(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.deleteAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setBiometricsEnabled_failsDisabling_whenPasphraseDeleteFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.deleteAccountPassphrase = always(.failure(.testError()))
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }

  func test_setBiometricsEnabled_failsEnabling_withNoSession() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setBiometricsEnabled_failsEnabling_withSessionAuthorizationRequired() {
    accountSession.statePublisher = always(
      Just(.authorizationRequired(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setBiometricsEnabled_failsEnabling_whenProfileSaveFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.failure(.testError()))
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }

  func test_setBiometricsEnabled_failsEnabling_withNoBiometricsPermission() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(false).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .permissionRequired)
  }

  func test_setBiometricsEnabled_failsEnabling_withPassphraseMissing() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorization = {}
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just(nil).eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    var result: TheError!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setBiometricsEnabled_savesPassphrase_whenEnabling() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    var result: Passphrase!
    accountsDataStore.storeAccountPassphrase = { _, passphrase in
      result = passphrase
      return .success
    }
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    feature
      .setBiometricsEnabled(true)
      .sink(receiveCompletion: { _ in }, receiveValue: {})
      .store(in: cancellables)

    XCTAssertEqual(result, "PASSPHRASE")
  }

  func test_setBiometricsEnabled_savesPassphraseForCurrentAccount_whenEnabling() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    var result: Account.LocalID!
    accountsDataStore.storeAccountPassphrase = { accountID, _ in
      result = accountID
      return .success
    }
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    feature
      .setBiometricsEnabled(true)
      .sink(receiveCompletion: { _ in }, receiveValue: {})
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount.localID)
  }

  func test_setBiometricsEnabled_deletesPassphraseForCurrentAccount_whenDisabling() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    var result: Account.LocalID!
    accountsDataStore.deleteAccountPassphrase = { accountID in
      result = accountID
      return .success
    }
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)
    passphraseCache.passphrasePublisher = always(Just("PASSPHRASE").eraseToAnyPublisher())
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()

    feature
      .setBiometricsEnabled(false)
      .sink(receiveCompletion: { _ in }, receiveValue: {})
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount.localID)
  }

  func test_accountProfilePublisher_publishesInitialProfile() {
    accountSession.statePublisher = always(
      CurrentValueSubject<AccountSession.State, Never>(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(
      Just(validAccountProfile.accountID).eraseToAnyPublisher()
    )
    features.use(accountsDataStore)
    features.use(permissions)
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()
    var result: AccountProfile!

    feature.accountProfilePublisher()
      .sink { profile in
        result = profile
      }
      .store(in: cancellables)

    XCTAssertEqual(result, validAccountProfile)
  }

  func test_accountProfilePublisher_publishesUpdatedProfile() {
    var currentAccountProfile: AccountProfile = validAccountProfile
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(currentAccountProfile))
    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountsDataStore.updatedAccountIDsPublisher = always(updatedAccountIDSubject.eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()
    var results: Array<AccountProfile> = .init()

    updatedAccountIDSubject.send(currentAccountProfile.accountID)

    feature.accountProfilePublisher()
      .sink { profile in
        results.append(profile)
      }
      .store(in: cancellables)

    updatedAccountIDSubject.send(currentAccountProfile.accountID)
    currentAccountProfile = otherValidAccountProfile
    updatedAccountIDSubject.send(currentAccountProfile.accountID)

    XCTAssertEqual(results.popLast(), otherValidAccountProfile)
    XCTAssertEqual(results.popLast(), validAccountProfile)
  }

  func test_accountProfilePublisher_completes_whenLoadingOfProfileFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.failure(.testError()))
    accountsDataStore.updatedAccountIDsPublisher = always(
      Just(validAccountProfile.accountID).eraseToAnyPublisher()
    )
    features.use(accountsDataStore)
    features.use(permissions)
    features.use(passphraseCache)

    let feature: AccountSettings = testInstance()
    var completed: Void!

    feature.accountProfilePublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion else {
            XCTFail("Unexpected error")
            return
          }

          completed = Void()
        },
        receiveValue: { _ in
          XCTFail("Unexpected value")
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(completed)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let otherValidAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "name lastName",
  username: "user",
  firstName: "name",
  lastName: "lastName",
  avatarImageURL: "otherAvatarImagePath",
  biometricsEnabled: true
)

// swift-format-ignore: NeverUseForceTry
private let validSessionTokens: SessionTokens = .init(
  accessToken: try! JWT.from(rawValue: validToken).get(),
  refreshToken: "REFRESH_TOKEN"
)

private let validToken: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """
