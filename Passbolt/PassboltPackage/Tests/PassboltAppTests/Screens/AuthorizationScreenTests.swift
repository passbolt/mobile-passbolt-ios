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

@testable import Accounts
import Combine
import Features
import NetworkClient
@testable import PassboltApp
import TestExtensions
import UIComponents
import XCTest

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
// swiftlint:disable implicitly_unwrapped_optional
// swiftlint:disable explicit_type_interface
final class AuthorizationScreenTests: TestCase {
  
  override func setUp() {
    super.setUp()
    
    var accounts: Accounts = .placeholder
    accounts.storedAccounts = always([account])
    features.use(accounts)
  }
  
  func test_forgotPassword_isPresented_whenCallingPresent() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Bool!
    
    controller.presentForgotPassphraseAlertPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)
    
    controller.presentForgotPassphraseAlert()
    
    XCTAssertTrue(result)
  }
  
  func test_validation_withCorrectValue_succeedes() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Validated<String>!
    
    controller.validatedPassphrasePublisher()
      .sink { validated in
        result = validated
      }
      .store(in: cancellables)
    
    controller.updatePassphrase("SomeSecretPassphrase")
    
    XCTAssertTrue(result.isValid)
    XCTAssertTrue(result.errors.isEmpty)
  }
  
  func test_validation_withInCorrectValue_failsWithValidationError() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Validated<String>!
    
    controller.validatedPassphrasePublisher()
      .sink { validated in
        result = validated
      }
      .store(in: cancellables)
    
    controller.updatePassphrase("")
    
    XCTAssertFalse(result.isValid)
    XCTAssertEqual(result.errors.first?.identifier, .validation)
  }
  
  func test_signIn_Succeeds() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Void?
    
    controller.updatePassphrase("Secret passphrase")
    controller.signIn()
      .sink { _ in
      } receiveValue: { value in
        result = value
      }
      .store(in: cancellables)
    
    XCTAssertNotNil(result)
  }
  
  func test_signIn_Fails() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var completionError: TheError?
    
    controller.updatePassphrase("Secret passphrase")
    controller.signIn()
      .sink { completion in
        switch completion {
        case let .failure(error):
          completionError = error
          
        case _:
          break
        }
      } receiveValue: { _ in
      }
      .store(in: cancellables)

    XCTAssertNotNil(completionError)
  }
  
  func test_biometricSignIn_Succeeds() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Void?
    
    controller.updatePassphrase("Secret passphrase")
    controller.biometricSignIn()
      .sink { _ in
      } receiveValue: { value in
        result = value
      }
      .store(in: cancellables)
    
    XCTAssertNotNil(result)
  }
  
  func test_biometricSignIn_Fails() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(.empty)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var completionError: TheError?
    
    controller.updatePassphrase("Secret passphrase")
    controller.biometricSignIn()
      .sink { completion in
        switch completion {
        case let .failure(error):
          completionError = error
          
        case _:
          break
        }
      } receiveValue: { _ in
      }
      .store(in: cancellables)

    XCTAssertNotNil(completionError)
  }
  
  func test_avatarPublisher_publishesData_whenNetworkRequest_Succeeds() {
    let testData: Data = .init(repeating: 1, count: 10)
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .respondingWith(testData)
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Data?
    
    controller.accountAvatarPublisher()
      .sink { data in
        result = data
      }
      .store(in: cancellables)
    
    XCTAssertEqual(result, testData)
  }
  
  func test_avatarPublisher_publishesNil_whenNetworkRequest_Fails() {
    var networkClient: NetworkClient = .placeholder
    networkClient.mediaDownload = .failingWith(.testError())
    features.use(networkClient)
    var accountSession: AccountSession = .placeholder
    accountSession.authorize = always(
      Just(()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSession)
    
    let controller: AuthorizationController = testInstance(context: account.localID)
    var result: Data?
    
    controller.accountAvatarPublisher()
      .sink { data in
        result = data
      }
      .store(in: cancellables)
    
    XCTAssertNil(result)
  }
}

private let account: AccountWithProfile = .init(
  localID: "localID",
  userID: "userID",
  domain: "passbolt.com",
  label: "passbolt",
  username: "username",
  firstName: "Adam",
  lastName: "Smith",
  avatarImageURL: "",
  fingerprint: "FINGERPRINT",
  biometricsEnabled: false
)
