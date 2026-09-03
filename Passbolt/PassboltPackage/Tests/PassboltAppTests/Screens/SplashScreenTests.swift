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

import CommonModels
import Features
import Localization
import OSFeatures
import SessionData
import SharedUIComponents
import TestExtensions

@testable import Accounts
@testable import Display
@testable import PassboltApp

/// Time allowed for a notice drawer to be presented before failing the test.
private let noticePresentationTimeout: TimeInterval = 1.0

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals

final class NewSplashScreenViewTests: FeaturesTestCase {

  var updates: Updates!

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    updates = .init()
    patch(
      \UpdateCheck.checkRequired,
      with: always(false)
    )
    patch(
      \UpdateCheck.updatePageURL,
      with: always(URLString?.none)
    )
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice?.none)
    )
    patch(
      \DeprecationCheck.markPresented,
      with: { (_: DeprecationNotice) in
        // NOP - withholding is covered by DeprecationCheckTests
      }
    )
    patch(
      \OSTime.waitForMilliseconds,
      with: { (_: Milliseconds) in
        // NOP - complete immediately for testing
      }
    )
    patch(
      \Session.updates,
      with: updates.asAnyUpdatable()
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \Session.pendingAuthorization,
      with: always(.none)
    )

    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \Accounts.verifyDataIntegrity,
      with: always(Void())
    )
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
  }

  func test_navigateToDiagnostics_whenDataIntegrityCheckFails() async throws {
    patch(
      \Accounts.verifyDataIntegrity,
      with: alwaysThrow(MockIssue.error())
    )

    try await verifyIfTriggersNavigation(NavigationToLogsViewer.self)
  }

  func test_navigateToAccountSetup_whenNoStoredAccounts() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    try await verifyIfTriggersNavigation(NavigationToWelcomeScreen.self)
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withAccount_andNotAuthorized() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    patch(
      \NavigationToAuthorization.mockPerform,
      with: always(self.mockExecuted())
    )

    try await verifyIfTriggersNavigation(
      NavigationToAccountSelection.self,
      with: Account.mock_ada,
      mocksTriggered: 2
    )
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withoutLastUsedAccount_andNotAuthorized() async throws
  {
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    try await verifyIfTriggersNavigation(
      NavigationToAccountSelection.self
    )
  }

  func test_navigateToHome_whenAuthorized_andFeatureFlagsDownloadSucceeds() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )

    try await verifyIfTriggersNavigation(
      NavigationToMainTabs.self
    )
  }

  func test_navigateToFeatureFlagsFetchError_whenAuthorized_andFeatureFlagsDownloadFails() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: alwaysThrow(MockIssue.error())
    )

    try await verifyIfTriggersNavigation(
      NavigationToStartupError.self
    )
  }

  func test_presentsDrawer_whenDeprecationNoticeIsPending() async throws {
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice.mock)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let awaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "deprecation drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [awaiter.expectation], timeout: noticePresentationTimeout)
      let notice: NoticeDrawerViewModel = try awaiter.presentedNotice()
      XCTAssertEqual(notice.title, DeprecationNotice.mock.title)
      XCTAssertEqual(notice.actions.count, 2)
      XCTAssertFalse(self.mockWasExecuted)

      try await notice.action(titled: .localized(key: .iUnderstand)).perform()
      await activation.value

      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  func test_silencesDeprecationNotice_whenSelectingDoNotShowAgain() async throws {
    let silenced: CriticalState<DeprecationNotice?> = .init(.none)
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice.mock)
    )
    patch(
      \DeprecationCheck.silence,
      with: { (notice: DeprecationNotice) in
        silenced.set(notice)
      }
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let awaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "deprecation drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [awaiter.expectation], timeout: noticePresentationTimeout)
      try await awaiter.presentedNotice().action(titled: .localized(key: .dontShowAgain)).perform()
      await activation.value

      XCTAssertEqual(silenced.get(), DeprecationNotice.mock)
      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  func test_withholdsDeprecationNotice_onlyAfterItWasPresented() async throws {
    let presented: CriticalState<DeprecationNotice?> = .init(.none)
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice.mock)
    )
    patch(
      \DeprecationCheck.markPresented,
      with: { (notice: DeprecationNotice) in
        presented.set(notice)
      }
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let awaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "deprecation drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [awaiter.expectation], timeout: noticePresentationTimeout)
      // an interruption at this point has to leave the notice pending
      XCTAssertNil(presented.get())

      try await awaiter.presentedNotice().action(titled: .localized(key: .iUnderstand)).perform()
      await activation.value

      XCTAssertEqual(presented.get(), DeprecationNotice.mock)
    }
  }

  func test_presentsDeprecationDrawerBeforeUpdateDrawer_whenBothArePending() async throws {
    patch(
      \UpdateCheck.checkRequired,
      with: always(true)
    )
    patch(
      \UpdateCheck.updateAvailable,
      with: always(true)
    )
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice.mock)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let deprecationAwaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "deprecation drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [deprecationAwaiter.expectation], timeout: noticePresentationTimeout)
      let deprecationNotice: NoticeDrawerViewModel = try deprecationAwaiter.presentedNotice()
      XCTAssertEqual(deprecationNotice.title, DeprecationNotice.mock.title)
      XCTAssertEqual(deprecationNotice.actions.count, 2)
      XCTAssertFalse(self.mockWasExecuted)

      // subscribed before the dismissal to not miss the drawer following it
      let updateAwaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "update drawer")
      )
      try await deprecationNotice.action(titled: .localized(key: .iUnderstand)).perform()

      await self.fulfillment(of: [updateAwaiter.expectation], timeout: noticePresentationTimeout)
      let updateNotice: NoticeDrawerViewModel = try updateAwaiter.presentedNotice()
      XCTAssertEqual(updateNotice.title, "update.available.title")
      // navigation is performed only after dismissing the last drawer
      XCTAssertFalse(self.mockWasExecuted)

      try await updateNotice.action(titled: .localized(key: .gotIt)).perform()
      await activation.value

      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  func test_presentsUpdateDrawerAfterSilencingDeprecationNotice_whenBothArePending() async throws {
    let silenced: CriticalState<DeprecationNotice?> = .init(.none)
    patch(
      \UpdateCheck.checkRequired,
      with: always(true)
    )
    patch(
      \UpdateCheck.updateAvailable,
      with: always(true)
    )
    patch(
      \DeprecationCheck.pendingNotice,
      with: always(DeprecationNotice.mock)
    )
    patch(
      \DeprecationCheck.silence,
      with: { (notice: DeprecationNotice) in
        silenced.set(notice)
      }
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let deprecationAwaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "deprecation drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [deprecationAwaiter.expectation], timeout: noticePresentationTimeout)
      // subscribed before the dismissal to not miss the drawer following it
      let updateAwaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "update drawer")
      )
      try await deprecationAwaiter.presentedNotice().action(titled: .localized(key: .dontShowAgain)).perform()

      await self.fulfillment(of: [updateAwaiter.expectation], timeout: noticePresentationTimeout)
      let updateNotice: NoticeDrawerViewModel = try updateAwaiter.presentedNotice()
      XCTAssertEqual(silenced.get(), DeprecationNotice.mock)
      XCTAssertEqual(updateNotice.title, "update.available.title")
      XCTAssertFalse(self.mockWasExecuted)

      try await updateNotice.action(titled: .localized(key: .gotIt)).perform()
      await activation.value

      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  func test_updateDrawerOpensStorePage_whenUpdatePageURLIsKnown() async throws {
    let openedURL: CriticalState<URLString?> = .init(.none)
    patch(
      \UpdateCheck.checkRequired,
      with: always(true)
    )
    patch(
      \UpdateCheck.updateAvailable,
      with: always(true)
    )
    patch(
      \UpdateCheck.updatePageURL,
      with: always(URLString?.some(.mockAppStore))
    )
    patch(
      \OSLinkOpener.openURL,
      with: { (url: URLString) in
        openedURL.set(url)
      }
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let awaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "update drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [awaiter.expectation], timeout: noticePresentationTimeout)
      let notice: NoticeDrawerViewModel = try awaiter.presentedNotice()
      XCTAssertEqual(notice.actions.count, 2)

      try await notice.action(titled: "update.available.action.title").perform()

      // the drawer stays up while the App Store is open - dismissing it here would
      // put the biometrics prompt on screen the moment the user comes back
      XCTAssertEqual(openedURL.get(), .mockAppStore)
      XCTAssertFalse(self.mockWasExecuted)

      try await notice.action(titled: .localized(key: .dismiss)).perform()
      await activation.value

      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  func test_updateDrawerOnlyAcknowledges_whenUpdatePageURLIsUnknown() async throws {
    patch(
      \UpdateCheck.checkRequired,
      with: always(true)
    )
    patch(
      \UpdateCheck.updateAvailable,
      with: always(true)
    )
    patch(
      \UpdateCheck.updatePageURL,
      with: always(URLString?.none)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    patch(
      \NavigationToMainTabs.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: .none
    ) { @MainActor feature in
      let awaiter: NoticeAwaiter = .init(
        observing: feature.viewState,
        expectation: self.expectation(description: "update drawer")
      )
      let activation: Task<Void, Never> = .init { await feature.activate() }
      defer { activation.cancel() }

      await self.fulfillment(of: [awaiter.expectation], timeout: noticePresentationTimeout)
      let notice: NoticeDrawerViewModel = try awaiter.presentedNotice()
      XCTAssertEqual(notice.actions.count, 1)

      try await notice.action(titled: .localized(key: .gotIt)).perform()
      await activation.value

      XCTAssertTrue(self.mockWasExecuted)
    }
  }

  private func verifyIfTriggersNavigation<N>(
    _: NavigationTo<N>.Type = NavigationTo<N>.self,
    with context: SplashScreenViewController.Context = .none,
    mocksTriggered: UInt = 1,
    file: StaticString = #file,
    line: UInt = #line,
  ) async throws where N: NavigationDestination {
    patch(
      \NavigationTo<N>.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: context,
      mockExecuted: mocksTriggered,
      file: file,
      line: line
    ) { @MainActor feature in
      await feature.activate()
    }
  }
}

/// Captures the first notice drawer reaching the view state after being created.
/// Subscribing up front instead of polling keeps the wait independent
/// of how the concurrently running activation is scheduled.
/// Uses Combine because it is the only observation point of `ViewStateSource`.
private final class NoticeAwaiter {

  fileprivate let expectation: XCTestExpectation
  private let captured: CriticalState<NoticeDrawerViewModel?> = .init(.none)
  private var subscription: AnyCancellable?

  fileprivate init(
    observing viewState: ViewStateSource<SplashScreenViewController.ViewState>,
    expectation: XCTestExpectation
  ) {
    self.expectation = expectation
    let captured: CriticalState<NoticeDrawerViewModel?> = self.captured
    self.subscription =
      viewState
      .updatesPublisher
      .compactMap { (state: SplashScreenViewController.ViewState) -> NoticeDrawerViewModel? in
        state.notice
      }
      .first()
      .sink { (notice: NoticeDrawerViewModel) in
        captured.set(notice)
        expectation.fulfill()
      }
  }

  fileprivate func presentedNotice(
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> NoticeDrawerViewModel {
    try XCTUnwrap(
      self.captured.get(),
      "Notice drawer was not presented",
      file: file,
      line: line
    )
  }
}

extension NoticeDrawerViewModel {

  /// Looks up an action by title to keep assertions independent of presentation order.
  fileprivate func action(
    titled title: DisplayableString,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> Action {
    try XCTUnwrap(
      self.actions.first { (action: Action) -> Bool in
        action.title == title
      },
      "Missing drawer action titled \(title)",
      file: file,
      line: line
    )
  }
}

extension URLString {

  fileprivate static var mockAppStore: Self {
    "https://apps.apple.com/app/passbolt"
  }
}

extension DeprecationNotice {

  fileprivate static var mock: Self {
    .init(
      identifier: "mock-deprecation-notice",
      title: "mock.deprecation.notice.title",
      messages: [
        "mock.deprecation.notice.message",
        "mock.deprecation.notice.message.action",
      ]
    )
  }
}
