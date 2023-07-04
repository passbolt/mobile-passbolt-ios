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
import OSFeatures
import Session
import UIComponents

internal struct BiometricsSetupController {

  internal var destinationPresentationPublisher: @MainActor () -> AnyPublisher<Destination, Never>
  internal var biometricsStatePublisher: @MainActor () -> AnyPublisher<OSBiometryAvailability, Never>
  internal var setupBiometrics: @MainActor () -> AnyPublisher<Never, Error>
  internal var skipSetup: @MainActor () -> Void
}

extension BiometricsSetupController {

  internal enum Destination {
    case finish
    case extensionSetup
  }
}

extension BiometricsSetupController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()

    let accountInitialSetup: AccountInitialSetup = try features.instance(context: currentAccount)
    let extensions: OSExtensions = features.instance()

    let applicationLifecycle: ApplicationLifecycle = features.instance()
    let accountPreferences: AccountPreferences = try features.instance(context: currentAccount)
    let biometry: OSBiometry = features.instance()

    let destinationPresentationSubject: PassthroughSubject<Destination, Never> = .init()

    func destinationPresentationPublisher() -> AnyPublisher<Destination, Never> {
      destinationPresentationSubject.eraseToAnyPublisher()
    }

    func biometricsStatePublisher() -> AnyPublisher<OSBiometryAvailability, Never> {
      Publishers.Merge(
        Just(biometry.availability()),
        applicationLifecycle
          .lifecyclePublisher()
          .compactMap { (transition: ApplicationLifecycle.Transition) -> OSBiometryAvailability? in
            if case .didBecomeActive = transition {
              return .none
            }
            else {
              return biometry.availability()
            }
          }
          .removeDuplicates()
      )
      .eraseToAnyPublisher()
    }

    func setupBiometrics() -> AnyPublisher<Never, Error> {
      accountInitialSetup.completeSetup(.biometrics)

      return Future<Void, Error> { promise in
        Task {
          do {
            try await accountPreferences.storePassphrase(true)
          }
          catch {
            Diagnostics.log(error: error)
            return promise(.failure(error))
          }
          if await extensions.autofillExtensionEnabled() {
            destinationPresentationSubject.send(.finish)
          }
          else {
            destinationPresentationSubject.send(.extensionSetup)
          }
          promise(.success)
        }
      }
      .ignoreOutput()
      .eraseToAnyPublisher()
    }

    func skipSetup() {
      accountInitialSetup.completeSetup(.biometrics)
      Task {
        if await extensions.autofillExtensionEnabled() {
          destinationPresentationSubject.send(.finish)
        }
        else {
          destinationPresentationSubject.send(.extensionSetup)
        }
      }
    }

    return Self(
      destinationPresentationPublisher: destinationPresentationPublisher,
      biometricsStatePublisher: biometricsStatePublisher,
      setupBiometrics: setupBiometrics,
      skipSetup: skipSetup
    )
  }
}
