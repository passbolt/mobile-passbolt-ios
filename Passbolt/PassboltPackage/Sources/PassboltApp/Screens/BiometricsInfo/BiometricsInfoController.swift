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

  public typealias Context = Void

  @MainActor internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()

    let accountInitialSetup: AccountInitialSetup = try features.instance(context: currentAccount)
    let extensions: OSExtensions = features.instance()
    let linkOpener: OSLinkOpener = features.instance()
    let biometry: OSBiometry = features.instance()
    let applicationLifecycle: ApplicationLifecycle = features.instance()

    let presentationDestinationSubject: PassthroughSubject<Destination, Never> = .init()

    var setupBiometricsCancellable: AnyCancellable?
    _ = setupBiometricsCancellable  // silence warning

    func destinationPresentationPublisher() -> AnyPublisher<Destination, Never> {
      presentationDestinationSubject.eraseToAnyPublisher()
    }

    func setupBiometrics() {
      accountInitialSetup.completeSetup(.biometrics)
      setupBiometricsCancellable =
        Just(Void())
        .asyncMap {
          do {
            try await linkOpener
              .openSystemSettings()
          }
          catch {
            diagnostics.log(error: error)
          }
        }
        .map { opened -> AnyPublisher<Bool, Never> in
          return applicationLifecycle.lifecyclePublisher()
            .map { (_: ApplicationLifecycle.Transition) -> Bool in
              switch biometry.availability() {
              case .unavailable, .unconfigured:
                return false

              case .faceID, .touchID:
                return true
              }
            }
            .removeDuplicates()
            .filter { $0 }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .sink { _ in
          presentationDestinationSubject.send(.biometricsSetup)
        }
    }

    func skipSetup() {
      accountInitialSetup.completeSetup(.biometrics)
      Task {
        if await extensions.autofillExtensionEnabled() {
          presentationDestinationSubject.send(.finish)
        }
        else {
          presentationDestinationSubject.send(.extensionSetup)
        }
      }
    }

    return Self(
      presentationDestinationPublisher: destinationPresentationPublisher,
      setupBiometrics: setupBiometrics,
      skipSetup: skipSetup
    )
  }
}
