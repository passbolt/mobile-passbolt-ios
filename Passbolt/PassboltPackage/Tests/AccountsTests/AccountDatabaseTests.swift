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
//final class AccountDatabaseTests: TestCase {
//
//  var accountSession: AccountSession!
//  var accountsDataStore: AccountsDataStore!
//  var databaseConnection: SQLiteConnection!
//
//  override func featuresActorSetUp() async throws {
//    try await super.featuresActorSetUp()
//    accountSession = .placeholder
//    accountsDataStore = .placeholder
//    databaseConnection = .placeholder
//  }
//
//  override func featuresActorTearDown() async throws {
//    accountSession = nil
//    accountsDataStore = nil
//    databaseConnection = nil
//    try await super.featuresActorTearDown()
//  }
//
//  func test_featureUnload_alwaysSucceeds() async throws {
//    accountSession.statePublisher = always(
//      Just(.authorized(validAccount))
//        .eraseToAnyPublisher()
//    )
//    await features.use(accountSession)
//    await features.patch(\AccountSession.databaseKey, with: always("database key"))
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    try await feature
//      .featureUnload()
//  }
//
//  func test_anyOperation_fails_whenDatabaseConnectionFails() async throws {
//    accountSession.statePublisher = always(
//      Just(.authorized(validAccount))
//        .eraseToAnyPublisher()
//    )
//    accountSession.databaseKey = always("database key")
//    await features.use(accountSession)
//    accountsDataStore.accountDatabaseConnection = alwaysThrow(MockIssue.error())
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Error?
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case let .failure(error) = completion
//          else { return }
//          result = error
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertUnderlyingError(
//      result,
//      root: DatabaseIssue.self,
//      matches: DatabaseConnectionClosed.self
//    )
//  }
//
//  func test_anyOperation_fails_whenSessionIsNone() async throws {
//    accountSession.statePublisher = always(
//      Just(.none(lastUsed: nil))
//        .eraseToAnyPublisher()
//    )
//    await features.use(accountSession)
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Error?
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case let .failure(error) = completion
//          else { return }
//          result = error
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertUnderlyingError(
//      result,
//      root: DatabaseIssue.self,
//      matches: DatabaseConnectionClosed.self
//    )
//  }
//
//  func test_anyOperation_fails_whenSessionIsAuthorizationRequiredAndApplicationEntersBackground() async throws {
//    try await FeaturesActor.execute {
//      self.environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
//    }
//    accountSession.statePublisher = always(
//      Just(.authorizationRequired(validAccount))
//        .eraseToAnyPublisher()
//    )
//    await features.use(accountSession)
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Error?
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case let .failure(error) = completion
//          else { return }
//          result = error
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertUnderlyingError(
//      result,
//      root: DatabaseIssue.self,
//      matches: DatabaseConnectionClosed.self
//    )
//  }
//
//  func test_anyOperation_fails_whenSessionIsAuthorizationRequiredAndConnectionWasNotActive() async throws {
//    try await FeaturesActor.execute {
//      self.environment.appLifeCycle.lifeCyclePublisher = always(Just(.willEnterForeground).eraseToAnyPublisher())
//    }
//    accountSession.statePublisher = always(
//      Just(.authorizationRequired(validAccount))
//        .eraseToAnyPublisher()
//    )
//    await features.use(accountSession)
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Error?
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case let .failure(error) = completion
//          else { return }
//          result = error
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertUnderlyingError(
//      result,
//      root: DatabaseIssue.self,
//      matches: DatabaseConnectionClosed.self
//    )
//  }
//
//  func test_anyOperation_isExecuted_whenSessionIsAuthorizationRequiredAndConnectionWasActive() async throws {
//    try await FeaturesActor.execute {
//      self.environment.appLifeCycle.lifeCyclePublisher = always(Just(.willEnterForeground).eraseToAnyPublisher())
//    }
//    accountSession.currentState = always(
//      .authorizationRequired(validAccount)
//    )
//
//    await features.use(accountSession)
//    await features.patch(\AccountSession.databaseKey, with: always("database key"))
//    databaseConnection.fetch = always(
//      [SQLiteRow(values: ["lastUpdateTimestamp": 0])]
//    )
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Void!
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case .finished = completion
//          else { return }
//          result = Void()
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertNotNil(result)
//  }
//
//  func test_anyOperation_fails_whenPassphraseIsNotAvailable() async throws {
//    try await FeaturesActor.execute {
//      self.environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
//    }
//    accountSession.statePublisher = always(
//      Just(.authorized(validAccount))
//        .eraseToAnyPublisher()
//    )
//    accountSession.databaseKey = alwaysThrow(MockIssue.error())
//    await features.use(accountSession)
//    databaseConnection.fetch = always(
//      [SQLiteRow(values: ["lastUpdateTimestamp": 0])]
//    )
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Error?
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case let .failure(error) = completion
//          else { return }
//          result = error
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertUnderlyingError(
//      result,
//      root: DatabaseIssue.self,
//      matches: DatabaseConnectionClosed.self
//    )
//  }
//
//  func test_anyOperation_isExecuted_whenSessionIsAuthorized() async throws {
//    try await FeaturesActor.execute {
//      self.environment.appLifeCycle.lifeCyclePublisher = always(Just(.didEnterBackground).eraseToAnyPublisher())
//    }
//    accountSession.statePublisher = always(
//      Just(.authorized(validAccount))
//        .eraseToAnyPublisher()
//    )
//    await features.use(accountSession)
//    await features.patch(\AccountSession.databaseKey, with: always("database key"))
//    databaseConnection.fetch = always(
//      [SQLiteRow(values: ["lastUpdateTimestamp": 0])]
//    )
//    accountsDataStore.accountDatabaseConnection = always(self.databaseConnection)
//    await features.use(accountsDataStore)
//
//    let feature: AccountDatabase = try await testInstance()
//
//    var result: Void!
//
//    feature
//      .fetchLastUpdate()
//      .sink(
//        receiveCompletion: { completion in
//          guard case .finished = completion
//          else { return }
//          result = Void()
//        },
//        receiveValue: { _ in }
//      )
//      .store(in: cancellables)
//
//    XCTAssertNotNil(result)
//  }
//}
//
//private let validAccount: Account = .init(
//  localID: .init(rawValue: UUID.test.uuidString),
//  domain: "https://passbolt.dev",
//  userID: "USER_ID",
//  fingerprint: "FINGERPRINT"
//)
