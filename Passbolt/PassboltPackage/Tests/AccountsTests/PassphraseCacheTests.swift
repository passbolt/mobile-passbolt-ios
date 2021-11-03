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

import CommonDataModels
import Commons
import Crypto
import Environment
import Features
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PassphraseCacheTests: TestCase {

  func test_passphraseIsStored_whenStoreIsCalled() {
    features.environment.time.timestamp = always(0)
    features.environment.appLifeCycle.lifeCyclePublisher = {
      Just(.didBecomeActive).eraseToAnyPublisher()
    }

    let cache: PassphraseCache = testInstance()

    let passphrase: Passphrase = "Passphrase to be stored"
    let accountID: Account.LocalID = "1"
    var result: Passphrase!

    cache.passphrasePublisher(accountID)
      .receive(on: ImmediateScheduler.shared)
      .sink { passphrase in
        result = passphrase
      }
      .store(in: cancellables)

    cache.store(passphrase, accountID, .distantFuture)

    XCTAssertEqual(passphrase, result)
  }

  func test_passphraseIsNotStored_whenStoreIsCalled_withExpirationDateInThePast() {
    features.environment.time.timestamp = always(0)
    features.environment.appLifeCycle.lifeCyclePublisher = {
      Just(.didBecomeActive).eraseToAnyPublisher()
    }

    let cache: PassphraseCache = testInstance()

    let passphrase: Passphrase = "Passphrase to be stored"
    let accountID: Account.LocalID = "1"
    var result: Passphrase?

    cache.passphrasePublisher(accountID)
      .receive(on: ImmediateScheduler.shared)
      .sink { passphrase in
        result = passphrase
      }
      .store(in: cancellables)

    cache.store(passphrase, accountID, .distantPast)

    XCTAssertNotEqual(passphrase, result)
    XCTAssertNil(result)
  }

  func test_alreadyStoredPassphraseIsCleared_whenClearIsCalled() {
    features.environment.time.timestamp = always(0)
    features.environment.appLifeCycle.lifeCyclePublisher = {
      Just(.didBecomeActive).eraseToAnyPublisher()
    }

    let cache: PassphraseCache = testInstance()

    let passphrase: Passphrase = "Passphrase to be stored"
    let accountID: Account.LocalID = "1"
    var result: Passphrase?

    cache.passphrasePublisher(accountID)
      .receive(on: ImmediateScheduler.shared)
      .sink { passphrase in
        result = passphrase
      }
      .store(in: cancellables)

    cache.store(passphrase, accountID, .distantFuture)

    XCTAssertEqual(passphrase, result)

    cache.clear()

    XCTAssertNotEqual(passphrase, result)
    XCTAssertNil(result)
  }

  func test_passphraseIsCleared_whenAppIsSentToBackground() {
    let lifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()

    features.environment.time.timestamp = always(0)
    features.environment.appLifeCycle.lifeCyclePublisher = {
      lifeCycleSubject.eraseToAnyPublisher()
    }

    let cache: PassphraseCache = testInstance()

    let passphrase: Passphrase = "Passphrase to be stored"
    let accountID: Account.LocalID = "1"
    var result: Passphrase!

    cache.passphrasePublisher(accountID)
      .receive(on: ImmediateScheduler.shared)
      .sink { passphrase in
        result = passphrase
      }
      .store(in: cancellables)

    cache.store(passphrase, accountID, .distantFuture)

    XCTAssertEqual(passphrase, result)

    lifeCycleSubject.send(.didEnterBackground)

    XCTAssertNil(result)
  }
}
