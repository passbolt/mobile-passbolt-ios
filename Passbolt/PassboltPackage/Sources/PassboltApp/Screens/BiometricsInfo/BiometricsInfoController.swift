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
import UIComponents
import Session

internal struct BiometricsInfoController {

  internal var presentationDestinationPublisher: @MainActor () -> AnyPublisher<Destination, Never>
  internal var setupBiometrics: @MainActor () -> Void
  internal var skipSetup: @MainActor () -> Void
}

extension BiometricsInfoController {

  internal enum Destination {

    case biometricsSetup
    case extensionSetup
    case finish
  }
}

extension BiometricsInfoController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let currentAccount: Account = try await features.instance(of: Session.self).currentAccount()
    let accountInitialSetup: AccountInitialSetup = try await features.instance(context: currentAccount)
    let autoFill: AutoFill = try await features.instance()
    let linkOpener: LinkOpener = try await features.instance()
    let biometry: Biometry = try await features.instance()

    let presentationDestinationSubject: PassthroughSubject<Destination, Never> = .init()

    var setupBiometricsCancellable: AnyCancellable?
    _ = setupBiometricsCancellable  // silence warning

    func destinationPresentationPublisher() -> AnyPublisher<Destination, Never> {
      presentationDestinationSubject.eraseToAnyPublisher()
    }

    func setupBiometrics() {
      accountInitialSetup.completeSetup(.biometrics)
      setupBiometricsCancellable =
        linkOpener
        .openSystemSettings()
        .map { opened -> AnyPublisher<Bool, Never> in
          guard opened
          else { return Empty().eraseToAnyPublisher() }
          return
            biometry
            .biometricsStatePublisher()
            .dropFirst()
            .map { (state: Biometrics.State) -> Bool in
              switch state {
              case .unavailable, .unconfigured:
                return false

              case .configuredTouchID, .configuredFaceID:
                return true
              }
            }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .filter { $0 }
        .sink { _ in
          presentationDestinationSubject.send(.biometricsSetup)
        }
    }

    func skipSetup() {
      accountInitialSetup.completeSetup(.biometrics)
      autoFill
        .extensionEnabledStatePublisher()
        .first()
        .sink { enabled in
          if enabled {
            presentationDestinationSubject.send(.finish)
          }
          else {
            presentationDestinationSubject.send(.extensionSetup)
          }
        }
        .store(in: cancellables)
    }

    return Self(
      presentationDestinationPublisher: destinationPresentationPublisher,
      setupBiometrics: setupBiometrics,
      skipSetup: skipSetup
    )
  }
}
