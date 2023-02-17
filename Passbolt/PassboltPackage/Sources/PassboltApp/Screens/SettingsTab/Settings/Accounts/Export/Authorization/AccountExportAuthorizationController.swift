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

struct AccountExportAuthorizationController {

  internal var viewState: MutableViewState<ViewState>

  internal var setPassphrase: @MainActor (Passphrase) -> Void
  internal var authorizeWithPassphrase: () -> Void
  internal var authorizeWithBiometrics: () -> Void
}

extension AccountExportAuthorizationController: ViewController {

  internal struct ViewState: Hashable {

    internal var accountLabel: String
    internal var accountUsername: String
    internal var accountDomain: String
    internal var accountAvatarImage: Data?
    internal var biometricsAvailability: OSBiometryAvailability
    internal var passphrase: Validated<Passphrase>
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      setPassphrase: unimplemented1(),
      authorizeWithPassphrase: unimplemented0(),
      authorizeWithBiometrics: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension AccountExportAuthorizationController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let features: Features = features.branch(scope: AccountTransferScope.self)

    let account: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let biometry: OSBiometry = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let accountPreferences: AccountPreferences = try features.instance(context: account)

    let accountDetails: AccountDetails = try features.instance(context: account)
    let accountExport: AccountChunkedExport = try features.instance()

    let passphraseValidator: Validator<Passphrase> = .nonEmpty(
      displayable: .localized(
        key: "authorization.passphrase.error"
      )
    )

    let accountWithProfile: AccountWithProfile = try accountDetails.profile()

    let biometricsAvailability: OSBiometryAvailability = {
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

    let viewState: MutableViewState<ViewState> = .init(
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

    asyncExecutor.schedule {
      do {
        let avatarImage: Data? = try await accountDetails.avatarImage()
        await viewState.update { (state: inout ViewState) in
          state.accountAvatarImage = avatarImage
        }
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    @MainActor func setPassphrase(
      _ passphrase: Passphrase
    ) {
      viewState.update(\.passphrase, to: passphraseValidator(passphrase))
    }

    nonisolated func authorizeWithPassphrase() {
      asyncExecutor.schedule(.reuse) {
        let validatedPassphrase: Validated<Passphrase> = await passphraseValidator(viewState.value.passphrase)
        do {
          let passphrase: Passphrase = try validatedPassphrase.validValue
          try await accountExport.authorize(.passphrase(passphrase))
          try await navigation.push(
            AccountQRCodeExportView.self,
            controller: features.instance()
          )
        }
        catch {
          await viewState.update { (state: inout ViewState) in
            state.passphrase = validatedPassphrase
            state.snackBarMessage = .error(error)
          }
          diagnostics.log(error: error)
        }
      }
    }

    nonisolated func authorizeWithBiometrics() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await accountExport.authorize(.biometrics)
          try await navigation.push(
            AccountQRCodeExportView.self,
            controller: features.instance()
          )
        }
        catch {
          await viewState.update { (state: inout ViewState) in
            state.snackBarMessage = .error(error)
          }
          diagnostics.log(error: error)
        }
      }
    }

    return .init(
      viewState: viewState,
      setPassphrase: setPassphrase(_:),
      authorizeWithPassphrase: authorizeWithPassphrase,
      authorizeWithBiometrics: authorizeWithBiometrics
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useAccountExportAuthorizationController() {
    use(
      .disposable(
        AccountExportAuthorizationController.self,
        load: AccountExportAuthorizationController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
