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
import FeatureScopes
import NetworkOperations
import OSFeatures
import SharedUIComponents

internal final class AuthorizationViewController: ViewController {

  internal typealias Context = Account

  internal struct ViewState: Equatable {

    internal var label: String = ""
    internal var username: String = ""
    internal var domain: String = ""
    internal var biometricsAvailability: OSBiometryAvailability = .unavailable
    internal var passphrase: Validated<String> = .valid("")
    internal var avatarData: Data? = nil
    internal var avatarURL: URLString? = nil
    internal var showLoadingOverlay: Bool = false
    internal var alert: Alert? = .none
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  fileprivate let features: Features
  fileprivate let context: Context
  fileprivate let navigationToSelf: NavigationToAuthorization
  fileprivate var attemptAutomaticBiometricSignTask: Task<Void, Never>? = .none

  internal init(context: Context, features: Features) throws {
    self.navigationToSelf = try features.instance()
    self.features = try features.branchIfNeeded(scope: AccountScope.self, context: context)
    self.context = context

    let accountDetails: AccountDetails = try self.features.instance()
    let biometry: OSBiometry = features.instance()

    self.viewState = .init(
      initial: .init(),
      updateFrom: accountDetails.updates,
      update: { updateState, _ in
        let passphraseStored: Bool = accountDetails.isPassphraseStored()
        let accountDetails: AccountWithProfile = try accountDetails.profile()
        let biometricAvailability: OSBiometryAvailability = biometry.availability()
          .accountAvailability(isPassphraseStored: passphraseStored)
        updateState { state in
          state.label = accountDetails.label
          state.username = accountDetails.username
          state.domain = accountDetails.domain.rawValue
          state.biometricsAvailability = biometricAvailability
          state.avatarURL = accountDetails.profile.avatarImageURL
        }
      }
    )
  }
}

extension AuthorizationViewController {

  internal struct Alert: Equatable {

    internal let title: DisplayableString
    internal let message: DisplayableString
  }

  internal func loadAvatar() async {
    await consumingErrors { @MainActor in
      let mediaDownloadOperation: MediaDownloadNetworkOperation = try features.instance()
      guard let avatarURL: URLString = await self.viewState.current.avatarURL
      else {
        return
      }
      let data: Data = try await mediaDownloadOperation.execute(avatarURL)
      self.viewState.update { state in
        state.avatarData = data
      }
    }
  }

  internal func back() async {
    await consumingErrors {
      let navigationToSelf: NavigationToAuthorization = try await features.instance()
      try await navigationToSelf.revert()
    }
  }

  @Sendable internal func presentHelp() async {
    await consumingErrors {
      let navigationToHelp: NavigationToHelpMenu = try await features.instance()
      try await navigationToHelp.perform(context: .init())
    }
  }

  internal func signIn() async {
    let passphraseString: String = await self.viewState.current.passphrase.value
    await self.signIn(
      using: .passphrase(
        self.context,
        .init(rawValue: passphraseString)
      )
    )
  }

  @discardableResult
  internal func tryBiometricSignIn() -> Task<Void, Never>? {
    guard self.attemptAutomaticBiometricSignTask == .none
    else {
      return .none
    }
    self.attemptAutomaticBiometricSignTask = Task { [weak self] in
      guard let self else {
        return
      }
      let currentState: ViewState = await self.viewState.current
      guard currentState.biometricsAvailability != .unavailable
      else {
        return
      }
      await self.biometricSignIn()
    }
    return self.attemptAutomaticBiometricSignTask
  }

  internal func biometricSignIn() async {
    await self.signIn(
      using: .biometrics(self.context)
    )
  }

  internal func forgotPassword() async {
    self.viewState.update { state in
      state.alert = .init(
        title: "authorization.forgot.passphrase.alert.title",
        message: "authorization.forgot.passphrase.alert.message"
      )
    }
  }

  private func signIn(using authorizationMethod: SessionAuthorizationMethod) async {
    do {
      let session: Session = try features.instance()
      viewState.update { state in
        state.showLoadingOverlay = true
      }
      try await session.authorize(authorizationMethod)
    }
    catch let error as ServerPGPFingeprintInvalid {
      await consumingErrors {
        let navigationToFingerprintInvalid: NavigationToServerFingerprintInvalid = try await features.instance()
        try await navigationToFingerprintInvalid.perform(
          context: .init(
            accountID: error.account.localID,
            fingerprint: error.fingerprint,
            backAction: {
              try await self.navigationToSelf.revert()
            }
          )
        )
      }
    }
    catch let serverError as ServerConnectionIssue {
      self.displayServerConnectionError(serverURL: serverError.serverURL)
    }
    catch let serverError as ServerResponseTimeout {
      self.displayServerConnectionError(serverURL: serverError.serverURL)
    }
    catch is CancellationError {
      // no-op, not an error
    }
    catch let error as SessionMFAAuthorizationRequired {
      // do not show error message, just log as user will be redirected to MFA screen
      error.logged()
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
      error.logged()
    }

    viewState.update { state in
      state.showLoadingOverlay = false
    }
  }

  private func displayServerConnectionError(serverURL: URLString) {
    viewState.update(
      \.alert,
      to: .init(
        title: "server.not.reachable.alert.title",
        message: .localized(
          key: "server.not.reachable.alert.message",
          arguments: [serverURL.rawValue]
        )
      )
    )
  }
}

#if DEBUG

extension AuthorizationViewController {

  internal static func previewDependencies(_ features: inout PreviewFeaturesContainer) {
    features.patch(
      \OSBiometry.availability,
      with: { @Sendable in .faceID }
    )
    features.patch(
      \AccountDetails.updates,
      with: Constant(()).asAnyUpdatable()
    )
    features.patch(
      \AccountDetails.profile,
      with: { .init(account: .ada, profile: .ada) }
    )
    features.patch(
      \MediaDownloadNetworkOperation.execute,
      with: { url in throw CancellationError.error() }
    )
    features.patch(
      \Session.authorize,
      with: { method in
        try await Task.sleep(seconds: 3)
        throw ServerPGPFingeprintInvalid.error(account: .ada, fingerprint: nil)
      }
    )
  }
}
#endif
