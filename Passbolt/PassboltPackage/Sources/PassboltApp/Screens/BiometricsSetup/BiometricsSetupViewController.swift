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
import Display
import OSFeatures

internal final class BiometricsSetupViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var icon: ImageNameConstant
    internal var title: DisplayableString
    internal var message: DisplayableString?
    internal var primaryButtonTitle: DisplayableString
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  let accountInitialSetup: AccountInitialSetup
  let extensions: OSExtensions
  let linkOpener: OSLinkOpener
  let accountPreferences: AccountPreferences
  let biometry: OSBiometry
  let navigationToExtensionSetup: NavigationToExtensionSetup
  let navigationToSelf: NavigationToBiometricsSetup

  internal init(context: (), features: Features) throws {

    let applicationLifecycle: ApplicationLifecycle = features.instance()
    let biometry: OSBiometry = features.instance()
    self.biometry = biometry
    let biometryUpdatable: AnyUpdatable<OSBiometryAvailability?> =
      applicationLifecycle
      .lifecycle
      .asAnyUpdatable(withInitial: .didBecomeActive)
      .map { (transition: ApplicationLifecycle.Transition) -> OSBiometryAvailability? in
        if case .didBecomeActive = transition {
          return .none
        }
        else {
          return biometry.availability()
        }
      }

    self.accountInitialSetup = try features.instance()
    self.extensions = features.instance()
    self.linkOpener = features.instance()
    self.accountPreferences = try features.instance()
    self.navigationToExtensionSetup = try features.instance()
    self.navigationToSelf = try features.instance()

    self.viewState = .init(
      initial: .init(
        icon: .biometrics,
        title: "",
        message: .none,
        primaryButtonTitle: ""
      ),
      updateFrom: biometryUpdatable,
      update: { update, biometryAvailability in
        let imageName: ImageNameConstant
        let title: DisplayableString
        let message: DisplayableString
        let primaryButtonTitle: DisplayableString

        switch try biometryAvailability.value {
        case .none, .unavailable, .unconfigured:
          imageName = .biometrics
          title = "biometrics.info.title"
          message = "biometrics.info.description"
          primaryButtonTitle = "biometrics.info.setup.button"
        case .faceID:
          imageName = .faceIDSetup
          title = "biometrics.setup.title.face"
          primaryButtonTitle = "biometrics.setup.setup.button.face"
          message = "biometrics.setup.description"
        case .touchID:
          imageName = .touchIDSetup
          title = "biometrics.setup.title.finger"
          primaryButtonTitle = "biometrics.setup.setup.button.finger"
          message = "biometrics.setup.description"
        }

        update {
          $0.icon = imageName
          $0.title = title
          $0.message = message
          $0.primaryButtonTitle = primaryButtonTitle
        }
      }
    )
  }

  internal func primaryButtonTapped() async {
    switch biometry.availability() {
    case .faceID, .touchID:
      await setupBiometrics()
    case .unconfigured, .unavailable:
      await openSettings()
    }
  }

  internal func skipSetup() async {
    accountInitialSetup.completeSetup(.biometrics)
    await nextStep()
  }

  private func nextStep() async {
    if await extensions.autofillExtensionEnabled() {
      await self.navigationToSelf.revertCatching()
    }
    else {
      await self.navigationToExtensionSetup.performCatching(context: .init(allowSkipping: true))
    }
  }

  internal func setupBiometrics() async {
    accountInitialSetup.completeSetup(.biometrics)

    do {
      try await accountPreferences.storePassphrase(true)
    }
    catch {
      SnackBarMessageEvent.send(.error(.localized(key: .genericError)))
    }
    await nextStep()
  }

  internal func openSettings() async {
    do {
      try await linkOpener
        .openSystemSettings()
    }
    catch {
      error.logged()
    }
  }
}
