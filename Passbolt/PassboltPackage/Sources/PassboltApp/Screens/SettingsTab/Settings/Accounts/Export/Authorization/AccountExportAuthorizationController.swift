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

import AccountSetup
import Accounts
import Display
import OSFeatures
import Session

internal final class AccountExportAuthorizationController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private nonisolated let passphraseValidator: Validator<Passphrase> = .nonEmpty(
    displayable: .localized(
      key: "authorization.passphrase.error"
    )
  )

  private let accountDetails: AccountDetails
  private let accountExport: AccountChunkedExport
  private let diagnostics: OSDiagnostics
  private let biometry: OSBiometry
  private let asyncExecutor: AsyncExecutor
  private let navigation: DisplayNavigation
  private let accountPreferences: AccountPreferences
  private let account: Account

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    self.features = features.branch(scope: AccountTransferScope.self)

    self.account = try features.sessionAccount()

    self.diagnostics = features.instance()
    self.biometry = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigation = try features.instance()
    self.accountPreferences = try features.instance(context: account)

    self.accountDetails = try features.instance(context: account)
    self.accountExport = try features.instance()

    let accountWithProfile: AccountWithProfile = try accountDetails.profile()

    let biometricsAvailability: OSBiometryAvailability = { [biometry, accountPreferences] in
      guard accountPreferences.isPassphraseStored()
      else { return .unavailable }
      switch biometry.availability() {
      case .unavailable, .unconfigured:
        return .unavailable
      case .faceID:
        return .faceID

      case .touchID:
        return .touchID
      }
    }()

    self.viewState = .init(
      initial:
        .init(
          accountLabel: accountWithProfile.label,
          accountUsername: accountWithProfile.username,
          accountDomain: account.domain.rawValue,
          accountAvatarImage: .none,
          biometricsAvailability: biometricsAvailability,
          passphrase: .valid("")
        )
    )

    self.asyncExecutor.scheduleCatchingWith(self.diagnostics) { [accountDetails, viewState] in
      let avatarImage: Data? = try await accountDetails.avatarImage()
      await viewState.update { (state: inout ViewState) in
        state.accountAvatarImage = avatarImage
      }
    }
  }
}

extension AccountExportAuthorizationController {

  internal struct ViewState: Hashable {

    internal var accountLabel: String
    internal var accountUsername: String
    internal var accountDomain: String
    internal var accountAvatarImage: Data?
    internal var biometricsAvailability: OSBiometryAvailability
    internal var passphrase: Validated<Passphrase>
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension AccountExportAuthorizationController {

  internal final func setPassphrase(
    _ passphrase: Passphrase
  ) {
    self.viewState.update(\.passphrase, to: passphraseValidator(passphrase))
  }

  internal final func authorizeWithPassphrase() {
    self.asyncExecutor.schedule(.reuse) { [unowned self] in
      let validatedPassphrase: Validated<Passphrase> = await self.passphraseValidator(self.viewState.value.passphrase)
      do {
        let passphrase: Passphrase = try validatedPassphrase.validValue
        try await self.accountExport.authorize(.passphrase(passphrase))
        try await self.navigation.push(
          AccountQRCodeExportView.self,
          controller: self.features.instance()
        )
      }
      catch {
        await self.viewState.update { (state: inout ViewState) in
          state.passphrase = validatedPassphrase
          state.snackBarMessage = .error(error)
        }
        self.diagnostics.log(error: error)
      }
    }
  }

  internal final func authorizeWithBiometrics() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failAction: { (error: Error) in
        await self.viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [features, accountExport, navigation] in
      try await accountExport.authorize(.biometrics)
      try await navigation.push(
        AccountQRCodeExportView.self,
        controller: features.instance()
      )
    }
  }
}
