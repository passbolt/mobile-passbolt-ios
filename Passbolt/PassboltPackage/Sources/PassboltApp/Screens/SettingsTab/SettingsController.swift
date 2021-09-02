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

internal struct SettingsController {

  internal var biometricsPublisher: () -> AnyPublisher<BiometricsState, Never>
  internal var biometricsDisableAlertPresentationPublisher: () -> AnyPublisher<Void, Never>
  internal var toggleBiometrics: () -> AnyPublisher<Never, TheError>
  internal var openTerms: () -> AnyPublisher<Bool, Never>
  internal var openPrivacyPolicy: () -> AnyPublisher<Bool, Never>
  internal var disableBiometrics: () -> AnyPublisher<Never, TheError>
  internal var signOutAlertPresentationPublisher: () -> AnyPublisher<Void, Never>
  internal var autoFillEnabledPublisher: () -> AnyPublisher<Bool, Never>
  internal var termsEnabled: () -> Bool
  internal var privacyPolicyEnabled: () -> Bool
  internal var presentSignOutAlert: () -> Void
}

extension SettingsController {

  internal enum BiometricsState: Equatable {
    case faceID(enabled: Bool)
    case touchID(enabled: Bool)
    case none
  }
}

extension SettingsController: UIController {

  internal typealias Context = Void

  static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> SettingsController {
    let accountSettings: AccountSettings = features.instance()
    let autoFill: AutoFill = features.instance()
    let biometry: Biometry = features.instance()
    let featureFlags: FeatureConfig = features.instance()
    let linkOpener: LinkOpener = features.instance()

    let legal: FeatureConfig.Legal = featureFlags.configuration()
    var termsURL: URL?
    var privacyPolicyURL: URL?

    (termsURL, privacyPolicyURL) = {
      switch legal {
      case .none:
        return (.none, .none)
      case let .terms(url):
        return (url, .none)
      case let .privacyPolicy(url):
        return (.none, url)
      case let .both(termsURL, privacyPolicyURL):
        return (termsURL, privacyPolicyURL)
      }
    }()

    let presentBiometricsAlertSubject: PassthroughSubject<Void, Never> = .init()
    let presentSignOutAlertSubject: PassthroughSubject<Void, Never> = .init()

    func biometricsStatePublisher() -> AnyPublisher<BiometricsState, Never> {
      Publishers.CombineLatest(
        biometry.biometricsStatePublisher(),
        accountSettings.currentAccountProfilePublisher()
      )
      .map { biometryState, accountProfile -> BiometricsState in
        switch biometryState {
        case .unavailable, .unconfigured:
          return .none

        case .configuredTouchID:
          return .touchID(enabled: accountProfile.biometricsEnabled)

        case .configuredFaceID:
          return .faceID(enabled: accountProfile.biometricsEnabled)
        }
      }
      .eraseToAnyPublisher()
    }

    func toggleBiometrics() -> AnyPublisher<Never, TheError> {
      accountSettings
        .biometricsEnabledPublisher()
        .first()
        .map { enabled -> AnyPublisher<Never, TheError> in
          if enabled {
            presentBiometricsAlertSubject.send()
            return Empty().eraseToAnyPublisher()
          }
          else {
            return
              accountSettings
              .setBiometricsEnabled(true)
              .ignoreOutput()
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func openTerms() -> AnyPublisher<Bool, Never> {
      guard
        let url = termsURL
      else {
        return Just(false).eraseToAnyPublisher()
      }

      return linkOpener.openLink(url)
    }

    func openPrivacyPolicy() -> AnyPublisher<Bool, Never> {
      guard
        let url = privacyPolicyURL
      else {
        return Just(false).eraseToAnyPublisher()
      }

      return linkOpener.openLink(url)
    }

    func disableBiometrics() -> AnyPublisher<Never, TheError> {
      accountSettings
        .setBiometricsEnabled(false)
        .ignoreOutput()
        .eraseToAnyPublisher()
    }

    func presentSignOutAlert() {
      presentSignOutAlertSubject.send()
    }

    func autoFillEnabledPublisher() -> AnyPublisher<Bool, Never> {
      autoFill.extensionEnabledStatePublisher()
    }

    func termsEnabled() -> Bool {
      termsURL != nil
    }

    func privacyPolicyEnabled() -> Bool {
      privacyPolicyURL != nil
    }

    return Self(
      biometricsPublisher: biometricsStatePublisher,
      biometricsDisableAlertPresentationPublisher: presentBiometricsAlertSubject.eraseToAnyPublisher,
      toggleBiometrics: toggleBiometrics,
      openTerms: openTerms,
      openPrivacyPolicy: openPrivacyPolicy,
      disableBiometrics: disableBiometrics,
      signOutAlertPresentationPublisher: presentSignOutAlertSubject.eraseToAnyPublisher,
      autoFillEnabledPublisher: autoFillEnabledPublisher,
      termsEnabled: termsEnabled,
      privacyPolicyEnabled: privacyPolicyEnabled,
      presentSignOutAlert: presentSignOutAlert
    )
  }
}
