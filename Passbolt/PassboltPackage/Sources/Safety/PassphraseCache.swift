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

import Accounts
import Commons
import Crypto
import Environment
import Features
import struct Foundation.Date
import enum Foundation.DispatchTimeInterval
import class Foundation.NSRecursiveLock

public struct PassphraseCache {
  // Get passphrase stored in memory - accountID used only for verification of stored data
  // If accountID does not match previously stored data then the cache is cleared.
  internal var passphrasePublisher: (_ accountID: Account.LocalID) -> AnyPublisher<Passphrase?, Never>
  // Store passphrase in memory for a specific accountID.
  internal var store: (
    _ passphrase: Passphrase,
    _ accountID: Account.LocalID,
    _ expirationDate: Date
  ) -> Void
  // Clear stored passphrase
  internal var clear: () -> Void
}

extension PassphraseCache {
  internal struct Entry {
    
    internal var accountID: Account.LocalID
    internal var value: String
    internal var expirationDate: Date
  }
}

extension PassphraseCache: Feature {
  
  public typealias Environment = (time: Time, lifeCycle: AppLifeCycle)
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (rootEnvironment.time, rootEnvironment.appLifeCycle)
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> PassphraseCache {
    let currentPassphraseSubject: CurrentValueSubject<Entry?, Never> = .init(nil)
    let lock: NSRecursiveLock = .init()
    var timer: DispatchedTimer?
    var sychronizedTimer: DispatchedTimer? {
      get {
        lock.lock()
        defer { lock.unlock() }
        return timer
      }
      
      set {
        lock.lock()
        timer = newValue
        lock.unlock()
      }
    }
    
    environment.lifeCycle
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
      .store(in: &cancellables)
    
    func clearCache() {
      currentPassphraseSubject.send(nil)
    }
    
    func createPassphrasePublisher(
      accountID: Account.LocalID
    ) -> AnyPublisher<Passphrase?, Never> {
      if let storedAccountId: Account.LocalID = currentPassphraseSubject.value?.accountID,
        accountID != storedAccountId {
        currentPassphraseSubject.send(nil)
      } else { /* */ }
      
      return currentPassphraseSubject
        .map { passphrase in
          guard let pass = passphrase,
            accountID == pass.accountID,
            Int(pass.expirationDate.timeIntervalSince1970) > environment.time.timestamp() else {
            return nil
          }
          
          return .init(rawValue: pass.value)
        }
        .eraseToAnyPublisher()
    }
    
    func setPassphrase(
      passphrase: Passphrase,
      accountID: Account.LocalID,
      expirationDate: Date
    ) {
      
      let passphrase: PassphraseCache.Entry = .init(
        accountID: accountID,
        value: .init(passphrase),
        expirationDate: expirationDate
      )
      
      let interval: DispatchTimeInterval = .seconds(.init(environment.time.timestamp()))
      
      sychronizedTimer = .init(interval: interval, handler: clearCache)
      
      currentPassphraseSubject.send(passphrase)
    }
    
    return Self(
      passphrasePublisher: createPassphrasePublisher(accountID:),
      store: setPassphrase(passphrase:accountID:expirationDate:),
      clear: clearCache
    )
  }
}

#if DEBUG
extension PassphraseCache {
  
  public static var placeholder: PassphraseCache {
    Self(
      passphrasePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      store: Commons.placeholder("You have to provide mocks for used methods"),
      clear: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
