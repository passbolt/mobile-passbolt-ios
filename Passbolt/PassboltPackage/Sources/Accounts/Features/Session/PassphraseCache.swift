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

import struct Foundation.Date
import enum Foundation.DispatchTimeInterval
import class Foundation.NSRecursiveLock
import struct Foundation.TimeInterval

internal struct PassphraseCache {
  // Get passphrase stored in memory - accountID used only for verification of stored data
  // If accountID does not match previously stored data then the cache is cleared.
  internal var passphrasePublisher:
    (
      _ accountID: Account.LocalID
    ) -> AnyPublisher<Passphrase?, Never>
  // Store passphrase in memory for a specific accountID.
  internal var store:
    (
      _ passphrase: Passphrase,
      _ accountID: Account.LocalID,
      _ expirationDate: Date
    ) -> Void
  // Clear stored passphrase
  internal var clear: () -> Void
}

extension PassphraseCache {

  internal static let defaultExpirationTimeInterval: TimeInterval = 5 * 60  // 5 minutes

  internal struct Entry {

    internal var accountID: Account.LocalID
    internal var value: Passphrase
    internal var expirationDate: Date
  }
}

extension PassphraseCache: Feature {

  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> PassphraseCache {
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle
    let time: Time = environment.time

    let diagnostics: Diagnostics = features.instance()

    let currentPassphraseEntrySubject: CurrentValueSubject<Entry?, Never> = .init(nil)
    let lock: NSRecursiveLock = .init()
    var timer: DispatchedTimer?

    appLifeCycle
      .lifeCyclePublisher()
      .sink { appState in
        switch appState {
        // App entered background or the screen was locked.
        case .didEnterBackground:
          clearCache()

        case _:
          // Do nothing
          break
        }
      }
      .store(in: cancellables)

    func clearCache() {
      diagnostics.debugLog("Clearing passphrase cache")
      lock.lock()
      timer?.cancel()
      timer = nil
      lock.unlock()
      currentPassphraseEntrySubject.send(nil)
    }

    func passphrasePublisher(
      for accountID: Account.LocalID
    ) -> AnyPublisher<Passphrase?, Never> {
      currentPassphraseEntrySubject
        .map { passphrase -> AnyPublisher<Passphrase?, Never> in
          guard let passphrase = passphrase
          else {
            return Just(nil)
              .eraseToAnyPublisher()
          }

          guard Int(passphrase.expirationDate.timeIntervalSince1970) > time.timestamp()
          else {
            currentPassphraseEntrySubject.send(nil)
            return Just(nil)
              .eraseToAnyPublisher()
          }

          guard accountID == passphrase.accountID
          else {
            return Empty()
              .eraseToAnyPublisher()
          }

          return Just(passphrase.value)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func setPassphrase(
      passphrase: Passphrase,
      accountID: Account.LocalID,
      expirationDate: Date
    ) {
      diagnostics.debugLog("Updating passphrase cache for \(accountID), auto expiring at \(expirationDate)")

      let cacheEntry: PassphraseCache.Entry = .init(
        accountID: accountID,
        value: passphrase,
        expirationDate: expirationDate
      )

      let interval: DispatchTimeInterval =
        .seconds(.init(Int(expirationDate.timeIntervalSince1970) - time.timestamp()))

      lock.lock()
      timer = .init(interval: interval, handler: clearCache)
      lock.unlock()

      currentPassphraseEntrySubject.send(cacheEntry)
    }

    return Self(
      passphrasePublisher: passphrasePublisher(for:),
      store: setPassphrase(passphrase:accountID:expirationDate:),
      clear: clearCache
    )
  }
}

#if DEBUG
extension PassphraseCache {

  internal static var placeholder: PassphraseCache {
    Self(
      passphrasePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      store: Commons.placeholder("You have to provide mocks for used methods"),
      clear: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
