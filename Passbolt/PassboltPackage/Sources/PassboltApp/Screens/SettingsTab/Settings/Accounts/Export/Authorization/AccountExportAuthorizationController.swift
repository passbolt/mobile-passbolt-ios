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
import FeatureScopes
import OSFeatures
import Session

internal final class AccountExportAuthorizationController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private nonisolated let passphraseValidator: Validator<Passphrase> = .nonEmpty(
    displayable: .localized(
      key: "authorization.passphrase.error"
    )
  )

  private let accountDetails: AccountDetails
  private let accountExport: AccountChunkedExport

  private let biometry: OSBiometry
  private let navigation: DisplayNavigation
  private let accountPreferences: AccountPreferences
  private let account: Account

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    let features: Features = try features.branch(scope: AccountTransferScope.self)
    self.features = features

    self.account = try features.sessionAccount()

    self.biometry = features.instance()
    self.navigation = try features.instance()
    self.accountPreferences = try features.instance()

    self.accountDetails = try features.instance()
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
        ),
        updateFrom: self.accountDetails.updates,
			update: { [accountDetails] updateView, _ in
				let avatarImage: Data? = try? await accountDetails.avatarImage()
				await updateView { (state: inout ViewState) in
					state.accountAvatarImage = avatarImage
				}
			}
    )
  }
}

extension AccountExportAuthorizationController {

  internal struct ViewState: Equatable {

    internal var accountLabel: String
    internal var accountUsername: String
    internal var accountDomain: String
    internal var accountAvatarImage: Data?
    internal var biometricsAvailability: OSBiometryAvailability
    internal var passphrase: Validated<Passphrase>
  }
}

extension AccountExportAuthorizationController {

  internal final func setPassphrase(
    _ passphrase: Passphrase
  ) {
    self.viewState.update(\.passphrase, to: passphraseValidator(passphrase))
  }

  internal final func authorizeWithPassphrase() async {
		let validatedPassphrase: Validated<Passphrase> = await self.passphraseValidator(self.viewState.current.passphrase)
		do {
			let passphrase: Passphrase = try validatedPassphrase.validValue
			try await self.accountExport.authorize(.passphrase(passphrase))
			try await self.navigation.push(
				AccountQRCodeExportView.self,
				controller: self.features.instance()
			)
		}
		catch {
			self.viewState.update { (state: inout ViewState) in
				state.passphrase = validatedPassphrase
			}
			error.consume()
		}
  }

  internal final func authorizeWithBiometrics() async {
		do {
			try await accountExport.authorize(.biometrics)
			try await navigation.push(
				AccountQRCodeExportView.self,
				controller: features.instance()
			)
		}
		catch {
			error.consume()
		}
  }
}
