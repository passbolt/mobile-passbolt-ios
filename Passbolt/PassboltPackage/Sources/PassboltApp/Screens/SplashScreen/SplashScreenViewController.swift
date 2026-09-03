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
import Commons
import Display
import FeatureScopes
import OSFeatures
import Session
import SessionData
import SharedUIComponents

internal final class SplashScreenViewController: ViewController {

  /// Time allowing the splash screen to settle before presenting anything on top of it.
  private static let initialPresentationDelay: Milliseconds = 300
  /// Time allowing a dismissed notice drawer to disappear before presenting the next one.
  private static let consecutiveNoticesDelay: Milliseconds = 400

  internal struct ViewState: Equatable {

    internal var notice: NoticeDrawerViewModel?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  private let accounts: Accounts
  private let session: Session
  private let sessionConfigurationLoader: SessionConfigurationLoader
  private let updateCheck: UpdateCheck
  private let deprecationCheck: DeprecationCheck
  private let linkOpener: OSLinkOpener
  private let time: OSTime
  private let context: Context
  private let features: Features

  internal init(context: Account?, features: Features) throws {
    self.context = context
    self.features = features
    self.accounts = try features.instance()
    self.session = try features.instance()
    self.sessionConfigurationLoader = try features.instance()
    self.updateCheck = try features.instance()
    self.deprecationCheck = try features.instance()
    self.linkOpener = features.instance()
    self.time = features.instance()

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
    do {
      try await self.time.waitForMilliseconds(Self.initialPresentationDelay)

      // ordered by presentation order
      var pendingNotices: Array<PendingNotice> = .init()
      if let notice: DeprecationNotice = self.deprecationCheck.pendingNotice() {
        pendingNotices.append(.deprecationNotice(notice))
      }
      if await self.shouldDisplayUpdateNotice() {
        pendingNotices.append(
          .updateAvailable(pageURL: await self.updateCheck.updatePageURL())
        )
      }

      try await self.present(notices: pendingNotices)

      if !pendingNotices.isEmpty {
        try await self.time.waitForMilliseconds(Self.consecutiveNoticesDelay)
      }  // else - nothing was presented
    }
    catch {
      self.viewState.update(\.notice, to: .none)
      guard !Task.isCancelled
      else { return }
      error.consumeSilently()
    }

    await showFeedbackAlertIfNeeded { [weak self] in
      try? await self?.handleNavigation(to: destination)
    }
  }

  /// Presents notice drawers one after another, returning after the last one is dismissed.
  /// Throws only when cancelled.
  private func present(
    notices: Array<PendingNotice>
  ) async throws {
    guard let firstNotice: PendingNotice = notices.first
    else { return }  // nothing to present

    try await self.presentAwaitingDismissal(of: firstNotice)
    for nextNotice: PendingNotice in notices.dropFirst() {
      // only a single sheet is presented at a time, the dismissed one
      // has to disappear before presenting the next
      try await self.time.waitForMilliseconds(Self.consecutiveNoticesDelay)
      try await self.presentAwaitingDismissal(of: nextNotice)
    }
  }

  /// Presents a single notice drawer, applying the choice made by the user on its dismissal.
  private func presentAwaitingDismissal(
    of notice: PendingNotice
  ) async throws {
    let dismissal: NoticeDismissal = try await futureValue {
      (dismiss: @escaping @Sendable (NoticeDismissal) -> Void) in
      self.viewState.update(
        \.notice,
        to: self.noticeViewModel(
          for: notice,
          dismiss: dismiss
        )
      )
    }
    self.viewState.update(\.notice, to: .none)

    if case .deprecationNotice(let deprecation) = notice {
      // withheld only after being seen - a presentation interrupted by cancellation
      // has to be repeated on the next splash screen entry within the same run
      self.deprecationCheck.markPresented(deprecation)
      if case .silenced = dismissal {
        self.deprecationCheck.silence(deprecation)
      }  // else - nothing to silence
    }  // else - nothing to withhold
  }

  private func noticeViewModel(
    for notice: PendingNotice,
    dismiss: @escaping @Sendable (NoticeDismissal) -> Void
  ) -> NoticeDrawerViewModel {
    switch notice {
    case .updateAvailable(let pageURL):
      return .init(
        title: "update.available.title",
        paragraphs: ["update.available.message"],
        actions: self.updateNoticeActions(
          pageURL: pageURL,
          dismiss: dismiss
        )
      )

    case .deprecationNotice(let deprecation):
      return .init(
        title: deprecation.title,
        icon: .startupWarning,
        paragraphs: deprecation.messages,
        actions: [
          .init(
            title: .localized(key: .iUnderstand),
            style: .primary,
            perform: { dismiss(.acknowledged) }
          ),
          .init(
            title: .localized(key: .dontShowAgain),
            style: .secondary,
            perform: { dismiss(.silenced) }
          ),
        ]
      )
    }
  }

  private func updateNoticeActions(
    pageURL: URLString?,
    dismiss: @escaping @Sendable (NoticeDismissal) -> Void
  ) -> Array<NoticeDrawerViewModel.Action> {
    guard let pageURL: URLString = pageURL
    // the App Store page is unknown - only acknowledging is available
    else {
      return [
        .init(
          title: .localized(key: .gotIt),
          style: .primary,
          perform: { dismiss(.acknowledged) }
        )
      ]
    }

    let linkOpener: OSLinkOpener = self.linkOpener
    return [
      .init(
        title: "update.available.action.title",
        style: .primary,
        perform: {
          // deliberately not dismissing - leaving the App Store would otherwise
          // land the user straight on the biometrics prompt, which reads as if
          // the App Store had asked for it
          do {
            try await linkOpener.openURL(pageURL)
          }
          catch {
            error.consumeSilently()
          }
        }
      ),
      .init(
        title: .localized(key: .dismiss),
        style: .secondary,
        perform: { dismiss(.acknowledged) }
      ),
    ]
  }

  private func shouldDisplayUpdateNotice() async -> Bool {
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
      try await self.features.navigateToMFAAuthorization(providers: mfaProviders)

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

  private enum PendingNotice: Equatable, Sendable {
    case updateAvailable(pageURL: URLString?)
    case deprecationNotice(DeprecationNotice)
  }

  /// The way a presented notice was dismissed by the user.
  private enum NoticeDismissal: Equatable, Sendable {
    /// Can be presented again.
    case acknowledged
    /// Must not be presented again.
    case silenced
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
