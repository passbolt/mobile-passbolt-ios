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

internal final class OperationAuthorizationViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var accountLabel: String
    internal var accountUsername: String
    internal var accountDomain: String
    internal var accountAvatarImage: Data?
    internal var biometricsAvailability: OSBiometryAvailability
    internal var passphrase: Validated<String>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private nonisolated let passphraseValidator: Validator<String> = .nonEmpty(
    displayable: .localized(
      key: "authorization.passphrase.error"
    )
  )

  internal let configuration: OperationAuthorizationConfiguration

  private let biometry: OSBiometry
  private let accountDetails: AccountDetails
  private let account: Account

  private let features: Features

  internal init(
    context: OperationAuthorizationConfiguration,
    features: Features
  ) throws {
    self.features = features

    self.configuration = context

    self.account = try features.accountContext()

    self.biometry = features.instance()

    self.accountDetails = try features.instance()

    self.viewState = .init(
      initial: .init(
        accountLabel: "",
        accountUsername: "",
        accountDomain: "",
        accountAvatarImage: .none,
        biometricsAvailability: .unavailable,
        passphrase: .valid("")
      ),
      updateFrom: self.accountDetails.updates,
      update: { [accountDetails, biometry] (updateView, _) in
        do {
          let accountWithProfile: AccountWithProfile = try accountDetails.profile()
          await updateView { (viewState: inout ViewState) in
            viewState.accountLabel = accountWithProfile.label
            viewState.accountUsername = accountWithProfile.username
          }
        }
        catch {
          error.consume(
            context: "Failed to update account profile details!"
          )
        }

        let biometricsAvailability: OSBiometryAvailability
        if accountDetails.isPassphraseStored() {
          switch biometry.availability() {
          case .unavailable, .unconfigured:
            biometricsAvailability = .unavailable
          case .faceID:
            biometricsAvailability = .faceID

          case .touchID:
            biometricsAvailability = .touchID
          }
        }
        else {
          biometricsAvailability = .unavailable
        }

        await updateView { (viewState: inout ViewState) in
          viewState.biometricsAvailability = biometricsAvailability
        }

        do {
          let accountAvatarImage: Data? = try await accountDetails.avatarImage()
          await updateView { (viewState: inout ViewState) in
            viewState.accountAvatarImage = accountAvatarImage
          }
        }
        catch {
          // do not present that on screen
          error.logged(
            info: .message(
              "Failed to update account avatar!"
            )
          )
        }
      }
    )
  }
}

extension OperationAuthorizationViewController {

  internal final func setPassphrase(
    _ passphrase: String
  ) {
    self.viewState.update(\.passphrase, to: passphraseValidator(passphrase))
  }

  internal final func authorizeWithPassphrase() async {
    let validatedPassphrase: Validated<String> = await self.passphraseValidator(self.viewState.current.passphrase)
    do {
      let passphrase: String = try validatedPassphrase.validValue
      try await self.configuration.operation(.passphrase(.init(rawValue: passphrase)))
    }
    catch {
      error.consume()
    }
  }

  internal final func authorizeWithBiometrics() async {
    guard self.accountDetails.isPassphraseStored()
    else { return }  // can't use biometry without passphrase
    do {
      try await self.configuration.operation(.biometrics)
    }
    catch {
      error.consume()
    }
  }
}
