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

@_exported import XCTest

internal class UITestCase: XCTestCase {

  internal var launcher: AppLauncher = .init()

  internal var application: XCUIApplication {
    get async {
      if let applicationValue = self.applicationValue {
        return applicationValue
      }
      let launcher: AppLauncher = self.launcher
      let application: XCUIApplication = await MainActor.run {
        let application: XCUIApplication = .init()
        var launchArguments: Array<String> = launcher.asLaunchArguments
        launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        application.launchArguments = launchArguments
        return application
      }
      self.applicationValue = application
      return application
    }
  }

  private var applicationValue: XCUIApplication?

  open func configureLauncher() {
    launcher
      .with(account: .automation)
  }

  override func setUp() async throws {
    try await super.setUp()
    self.configureLauncher()
    self.continueAfterFailure = false
    let application: XCUIApplication = await self.application
    await application.launch()
    await MainActor.run {
      UITestFlow(application: application) {
        Login(account: .automation)
        On(HomeScreen.self, timeout: .networkCall) { _ in
          // Nothing to do here, just waiting for the home screen to be loaded
        }
        On(HomeListScreen.self) { screen in
          WaitForRefreshToComplete(screen.list, timeout: 60)
        }
      }
      .run()
    }
  }

  @MainActor override func waitForExpectations(timeout: TimeInterval, handler: (@Sendable ((any Error)?) -> Void)? = nil) {
    assertionFailure("Use XCTNSPredicateExpectation instead of XCTExpectation in UITests")
  }

  /// Awaits the launched `XCUIApplication`, builds a `UITestFlow` for the supplied steps and runs it.
  /// Failures are reported at the originating step's source location (see `LocatedError`).
  @MainActor
  internal func executeSteps(
    _ name: String = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    @UITestStepsBuilder _ steps: () -> Array<UITestStep>
  ) async {
    let application: XCUIApplication = await self.application
    UITestFlow(name, application: application, steps)
      .run(file: file, line: line)
  }
}

internal struct AppLauncher {

  private(set) fileprivate var accounts: Array<MockAccount> = .init()
  private(set) fileprivate var lastUsedAccountID: String?

  @discardableResult
  mutating internal func with(account: MockAccount) -> Self {
    self.accounts.append(account)
    return self
  }

  @discardableResult
  mutating internal func with(lastUsedAccountID: String) -> Self {
    self.lastUsedAccountID = lastUsedAccountID
    return self
  }

  fileprivate var asLaunchArguments: Array<String> {
    var launchArguments: Array<String> = .init()
    if self.accounts.isEmpty {
      launchArguments.append("-com.apple.configuration.managed")
      launchArguments.append("<dict><key>accounts</key><array></array><key>disableUpdateCheck</key><true/></dict>")
      launchArguments.append("-accountsList")
      launchArguments.append("<array></array>")
      launchArguments.append("-lastUsedAccount")
      launchArguments.append("")
    }
    else {
      let encodedAccounts: String = self.accounts.reduce(into: "") { $0.append($1.plistArgsEncoded) }
      launchArguments.append("-com.apple.configuration.managed")
      launchArguments.append("<dict><key>accounts</key><array>\(encodedAccounts)</array><key>disableUpdateCheck</key><true/></dict>")
      launchArguments.append("-lastUsedAccount")
      launchArguments.append("\(self.lastUsedAccountID ?? "")")
    }
    // We also want to reset the timestamp of the last app rate check and the login count
    // to avoid having the rating pop up during tests
    launchArguments.append("-lastAppRateCheckTimestamp")
    launchArguments.append("0")
    launchArguments.append("-loginCount")
    launchArguments.append("0")
    launchArguments.append("-force-skip-setup")
    launchArguments.append("<true/>")
    return launchArguments
  }
}


final class AsyncLazy<T: Sendable>: @unchecked Sendable {
  private var task: Task<T, Error>?
  private let operation: @Sendable () async throws -> T
  private let lock = NSLock()

  init(operation: @escaping @Sendable () async throws -> T) {
    self.operation = operation
  }

  var value: T {
    get async throws {
      let task: Task<T, Error> = lock.withLock {
        if let existing = self.task { return existing }
        let newTask = Task { try await operation() }
        self.task = newTask
        return newTask
      }
      return try await task.value
    }
  }
}
