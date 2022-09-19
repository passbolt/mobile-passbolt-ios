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
import Session
import UIComponents

internal struct BiometricsSetupController {

  internal var destinationPresentationPublisher: @MainActor () -> AnyPublisher<Destination, Never>
  internal var biometricsStatePublisher: @MainActor () -> AnyPublisher<Biometrics.State, Never>
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
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let currentAccount: Account = try await features.instance(of: Session.self).currentAccount()
    let accountInitialSetup: AccountInitialSetup = try await features.instance(context: currentAccount)
    let autoFill: AutoFill = try await features.instance()
    let diagnostics: Diagnostics = features.instance()
    let session: Session = try await features.instance()
    let accountPreferences: AccountPreferences = try await features.instance(context: session.currentAccount())
    let biometry: Biometry = try await features.instance()

    let destinationPresentationSubject: PassthroughSubject<Destination, Never> = .init()

    func destinationPresentationPublisher() -> AnyPublisher<Destination, Never> {
      destinationPresentationSubject.eraseToAnyPublisher()
    }

    func biometricsStatePublisher() -> AnyPublisher<Biometrics.State, Never> {
      biometry.biometricsStatePublisher()
    }

    func setupBiometrics() -> AnyPublisher<Never, Error> {
      accountInitialSetup.completeSetup(.biometrics)
      return Just(Void())
        .eraseErrorType()
        .asyncMap {
          try await accountPreferences.storePassphrase(true)
        }
        .map { autoFill.extensionEnabledStatePublisher().eraseErrorType() }
        .switchToLatest()
        .handleEvents(receiveOutput: { enabled in
          if enabled {
            destinationPresentationSubject.send(.finish)
          }
          else {
            destinationPresentationSubject.send(.extensionSetup)
          }
        })
        .ignoreOutput()
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }

    func skipSetup() {
      accountInitialSetup.completeSetup(.biometrics)
      autoFill
        .extensionEnabledStatePublisher()
        .first()
        .sink { enabled in
          if enabled {
            destinationPresentationSubject.send(.finish)
          }
          else {
            destinationPresentationSubject.send(.extensionSetup)
          }
        }
        .store(in: cancellables)
    }

    return Self(
      destinationPresentationPublisher: destinationPresentationPublisher,
      biometricsStatePublisher: biometricsStatePublisher,
      setupBiometrics: setupBiometrics,
      skipSetup: skipSetup
    )
  }
}
