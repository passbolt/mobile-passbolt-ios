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
import Session
import SessionData
import SharedUIComponents

internal final class SplashScreenViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var alert: AlertViewModel?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  private let accounts: Accounts
  private let session: Session
  private let sessionConfigurationLoader: SessionConfigurationLoader
  private let updateCheck: UpdateCheck
  private let context: Context
  private let features: Features

  internal init(context: Account?, features: Features) throws {
    self.context = context
    self.features = features
    self.accounts = try features.instance()
    self.session = try features.instance()
    self.sessionConfigurationLoader = try features.instance()
    self.updateCheck = try features.instance()

    self.viewState = .init(
      initial: .init()
    )
  }

  @Sendable internal func activate() async {
    do {
      try accounts.verifyDataIntegrity()
    }
    catch {
      return await navigate(to: .diagnostics)
    }

    let storedAccounts: Array<AccountWithProfile> = accounts.storedAccounts()

    if storedAccounts.isEmpty {
      return await navigate(to: .accountSetup)
    }
    else if let currentAccount: Account =
      try? await session.currentAccount(),
      currentAccount == context || context == .none
    {
      switch await session.pendingAuthorization() {
      case .none:
        do {
          return
            try await navigate(
              to: .home(
                .init(
                  account: currentAccount,
                  configuration: sessionConfigurationLoader.sessionConfiguration()
                )
              )
            )
        }
        catch {
          return await navigate(to: .featureConfigFetchError)
        }

      case .mfa(_, let mfaProviders):
        return await navigate(to: .mfaAuthorization(mfaProviders))

      case .passphrase(let account):
        return await navigate(to: .accountSelection(account, message: "authorization.prompt.refresh.session.reason"))
      }
    }
    else {
      return await navigate(to: .accountSelection(context, message: .none))
    }
  }

  private func navigate(to destination: Destination) async {
    try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s
    let performNavigation: @Sendable () async -> Void = { @MainActor [weak self] in
      await showFeedbackAlertIfNeeded {
        try? await self?.handleNavigation(to: destination)
      }
    }
    let presentUpdateAlert: Bool = await self.shouldDisplayUpdateAlert()
    if presentUpdateAlert {
      viewState.update(
        \.alert,
        to: .init(
          title: "update.available.title",
          message: "update.available.message",
          actions: [
            .regular(
              id: .init(),
              title: .localized(key: .gotIt),
              perform: performNavigation
            )
          ]
        )
      )
    }
    else {
      await performNavigation()
    }
  }

  private func shouldDisplayUpdateAlert() async -> Bool {
    guard await updateCheck.checkRequired()
    else { return false }

    do {
      return try await updateCheck.updateAvailable()
    }
    catch {
      return false
    }
  }

  private func handleNavigation(to destination: Destination) async throws {
    switch destination {
    case .accountSelection(let lastAccount, let message):
      let navigationToAccountSelection: NavigationToAccountSelection = try self.features.instance()
      try await navigationToAccountSelection.perform(
        context: .init(isSignIn: true)
      )
      if let message {
        SnackBarMessageEvent.send(.info(message))
      }
      if let lastAccount {
        let navigationToAuthorization: NavigationToAuthorization = try self.features.instance()
        try await navigationToAuthorization.perform(context: lastAccount)
      }

    case .accountSetup:
      let navigationToWelcomeScreen: NavigationToWelcomeScreen = try self.features.instance()
      try await navigationToWelcomeScreen.perform()

    case .diagnostics:
      let navigationToLogsViewer: NavigationToLogsViewer = try self.features.instance()
      try await navigationToLogsViewer.perform(context: .init(useCustomNavigationBar: true))

    case .home(let sessionContext):
      let navigationToLogsViewer: NavigationToMainTabs = try self.features
        .instance()
      try await navigationToLogsViewer.perform(context: sessionContext)

    case .mfaAuthorization(let mfaProviders):
      if mfaProviders.isEmpty {
        let navigationToUnsupportedMFA: NavigationToUnsupportedMFA = try self.features.instance()
        try await navigationToUnsupportedMFA.perform()
      }
      else {
        let navigationToMFA: NavigationToMFA = try self.features.instance()
        try await navigationToMFA.perform(context: mfaProviders)
      }

    case .featureConfigFetchError:
      let navigationToError: NavigationToStartupError = try self.features.instance()
      try await navigationToError.perform(
        context: { [weak self] in
          try await self?.retryFetchConfiguration()
        }
      )
    }
  }

  @Sendable nonisolated func retryFetchConfiguration() async throws {
    try await handleNavigation(
      to: .home(
        .init(
          account: try session.currentAccount(),
          configuration: sessionConfigurationLoader.sessionConfiguration()
        )
      )
    )
  }

  private enum Destination {
    case accountSetup
    case accountSelection(Account?, message: DisplayableString?)
    case diagnostics
    case home(SessionScope.Context)
    case mfaAuthorization(Array<SessionMFAProvider>)
    case featureConfigFetchError
  }
}
