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
final class AccountDatabaseTests: TestCase {

  var accountSession: AccountSession!
  var accountsDataStore: AccountsDataStore!
  var databaseConnection: SQLiteConnection!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    accountsDataStore = .placeholder
    databaseConnection = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    accountsDataStore = nil
    databaseConnection = nil
    super.tearDown()
  }

  func test_featureUnload_alwaysSucceeds() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.patch(\AccountSession.databaseKey, with: always("database key"))
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    let result: Bool =
      feature
      .featureUnload()

    XCTAssertTrue(result)
  }

  func test_anyOperation_fails_whenDatabaseConnectionFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.databaseKey = always("database key")
    features.use(accountSession)
    accountsDataStore.accountDatabaseConnection = always(.failure(.testError()))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: TheError!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .databaseConnectionClosed)
  }

  func test_anyOperation_fails_whenSessionIsNone() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: nil))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: TheError!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .databaseConnectionClosed)
  }

  func test_anyOperation_fails_whenSessionIsAuthorizationRequiredAndApplicationEntersBackground() {
    environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
    accountSession.statePublisher = always(
      Just(.authorizationRequired(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: TheError!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .databaseConnectionClosed)
  }

  func test_anyOperation_fails_whenSessionIsAuthorizationRequiredAndConnectionWasNotActive() {
    environment.appLifeCycle.lifeCyclePublisher = always(Just(.willEnterForeground).eraseToAnyPublisher())
    accountSession.statePublisher = always(
      Just(.authorizationRequired(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: TheError!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .databaseConnectionClosed)
  }

  func test_anyOperation_isExecuted_whenSessionIsAuthorizationRequiredAndConnectionWasActive() {
    environment.appLifeCycle.lifeCyclePublisher = always(Just(.willEnterForeground).eraseToAnyPublisher())
    accountSession.statePublisher = always(
      [.authorized(validAccount), .authorizationRequired(validAccount)]
        .publisher
        .eraseToAnyPublisher()
    )

    features.use(accountSession)
    features.patch(\AccountSession.databaseKey, with: always("database key"))
    databaseConnection.fetch = always(
      .success([SQLiteRow(values: ["lastUpdateTimestamp": 0])])
    )
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: Void!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_anyOperation_fails_whenPassphraseIsNotAvailable() {
    environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.databaseKey = always(nil)
    features.use(accountSession)
    databaseConnection.fetch = always(
      .success([SQLiteRow(values: ["lastUpdateTimestamp": 0])])
    )
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: TheError?

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .databaseConnectionClosed)
  }

  func test_anyOperation_isExecuted_whenSessionIsAuthorized() {
    environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.patch(\AccountSession.databaseKey, with: always("database key"))
    databaseConnection.fetch = always(
      .success([SQLiteRow(values: ["lastUpdateTimestamp": 0])])
    )
    databaseConnection.enqueueOperation = { $0() }
    accountsDataStore.accountDatabaseConnection = always(.success(self.databaseConnection))
    features.use(accountsDataStore)

    let feature: AccountDatabase = testInstance()

    var result: Void!

    feature
      .fetchLastUpdate()
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)
