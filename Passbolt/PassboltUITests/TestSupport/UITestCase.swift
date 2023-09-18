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

import XCTest

internal class UITestCase: XCTestCase {

  // MARK: - Initialization

  internal final lazy var application: XCUIApplication = {
    let application: XCUIApplication = .init()
    var launchArguments: Array<String> = self.applicationLaunchArguments
    if self.initialAccounts.isEmpty {
      launchArguments.append("-com.apple.configuration.managed")
      launchArguments.append("<dict><key>accounts</key><array></array></dict>")
      launchArguments.append("-accountsList")
      launchArguments.append("<array></array>")
      launchArguments.append("-lastUsedAccount")
      launchArguments.append("")
    }
    else {
      let encodedAccounts: String = self.initialAccounts.reduce(into: "") { $0.append($1.plistArgsEncoded) }
      launchArguments.append("-com.apple.configuration.managed")
      launchArguments.append("<dict><key>accounts</key><array>\(encodedAccounts)</array></dict>")
      launchArguments.append("-lastUsedAccount")
      launchArguments.append("\(self.lastUsedAccountID ?? "")")
      for account in self.initialAccounts {
        switch (self.unfinishedBiometrySetup, self.unfinishedAutofillSetup) {
        case (true, true):
          launchArguments.append("-unfinishedSetup-\(account.userID)")
          launchArguments.append("<array><string>biometrics</string><string>autofill</string></array>")

        case (false, true):
          launchArguments.append("-unfinishedSetup-\(account.userID)")
          launchArguments.append("<array><string>autofill</string></array>")

        case (true, false):
          launchArguments.append("-unfinishedSetup-\(account.userID)")
          launchArguments.append("<array><string>biometrics</string></array>")

        case (false, false):
          launchArguments.append("-unfinishedSetup-\(account.userID)")
          launchArguments.append("<array></array>")
        }
      }
    }
    launchArguments.append("-lastAppRateCheckTimestamp")
    launchArguments.append("\(self.lastAppRateCheckTimestamp)")
    launchArguments.append("-loginCount")
    launchArguments.append("\(self.loginCount)")
    application.launchArguments = launchArguments
    self.applicationSetup(application: application)
    application.launch()
    return application
  }()
  internal private(set) lazy var safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

  /// Prepare ``XCUIApplication``
  internal func applicationSetup(
    application: XCUIApplication
  ) {
    // to be overriden
  }

  internal func beforeEachTestCase() throws {
    // to be overriden
  }

  internal func afterEachTestCase() throws {
    // to be overriden
  }

  override final func setUpWithError() throws {
    try super.setUpWithError()
    try beforeEachTestCase()
  }

  override final func tearDownWithError() throws {
    try afterEachTestCase()
    try super.tearDownWithError()
  }

  // MARK: - Device

  internal final func rotateDevice(
    _ orientation: UIDeviceOrientation
  ) {
    XCUIDevice.shared.orientation = orientation
  }

  // MARK: - Test parameters

  /// Any custom arguments passed on application launch.
  /// Do not put there automaticaly generated arguments.
  internal var applicationLaunchArguments: Array<String> { .init() }
  /// List of accounts which will be set up in the application after launching.
  internal var initialAccounts: Array<MockAccount> { [.automation] }
  /// ID of last used account if any
  internal var lastUsedAccountID: String? { MockAccount.automation.userID }
  /// Timestamp of last application rating check, epoch time seconds
  internal var lastAppRateCheckTimestamp: Int { 0 }
  /// Count of application logins
  internal var loginCount: Int { 0 }
  internal var unfinishedAutofillSetup: Bool { false }
  internal var unfinishedBiometrySetup: Bool { false }

  // MARK: - Test support

  internal final func makeScreenshotAttachment(
    _ lifetime: XCTAttachment.Lifetime = .deleteOnSuccess,
    name: String = #function
  ) {
    let attachment: XCTAttachment = .init(
      screenshot: self.application.screenshot()
    )
    attachment.name = name
    attachment.lifetime = lifetime
    self.add(attachment)
  }

  internal final func waitForElement(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: TimeInterval = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let element: XCUIElement
    if let specifier {
      element = self.application
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: specifier
        )
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: identifier
        )
    }
    else {
      element = self.application
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: identifier
        )
    }

    let exists: Bool =
      element.exists
      ? true
      : element.waitForExistence(timeout: timeout)

    if !exists {
      throw
        TestFailure
        .error(
          message: "Required element \"\(identifier)\" \(specifier.map { " inside \"\($0)\"" } ?? "") does not exists!",
          file: file,
          line: line
        )
    }  // else either exists or not required
  }

  internal final func element(
    _ identifier: String,
    inside specifier: String?,
    timeout: TimeInterval = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws -> XCUIElement {
    let element: XCUIElement
    if let specifier {
      element = self.application
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: specifier
        )
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: identifier
        )
    }
    else {
      element = self.application
        .descendants(matching: .any)
        .element(
          matching: .any,
          identifier: identifier
        )
    }

    let exists: Bool =
      element.exists
      ? true
      : element.waitForExistence(timeout: timeout)

    if !exists {
      throw
        TestFailure
        .error(
          message: "Required element \"\(identifier)\"\(specifier.map { " inside \"\($0)\" " } ?? "") does not exists!",
          file: file,
          line: line
        )
    }
    else {
      return element
    }
  }

  // MARK: - Interactions

  internal final func selectCollectionViewItem(
    identifier: String,
    inside specifier: String? = .none,
    at index: Int,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    try element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    .children(matching: .cell)
    .element(boundBy: 0)
    .tap()
  }

  internal final func tap(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    try self.element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    .tap()
  }

  internal final func tapTab(
    _ identifier: String,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let element: XCUIElement = self.application
      .tabBars
      .buttons
      .element(
        matching: .button,
        identifier: identifier
      )

    let exists: Bool =
      element.exists
      ? true
      : element.waitForExistence(timeout: timeout)

    if !exists {
      throw
        TestFailure
        .error(
          message: "Required element \"\(identifier)\" does not exists!",
          file: file,
          line: line
        )
    }
    else {
      element.tap()
    }
  }

  internal final func swipeUp(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    try self.element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    .swipeUp()
  }

  internal final func swipeDown(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    try self.element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    .swipeDown()
  }

  internal final func type(
    text value: String,
    to identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let element: XCUIElement = try self.element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    element.tap()  // to gain focus
    element.typeText(value)
  }

  // MARK: - Verify

  internal final func assert(
    _ identifier: String,
    inside specifier: String? = .none,
    textEqual text: String,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      let label: String =
        try self.element(
          identifier,
          inside: specifier,
          timeout: timeout,
          file: file,
          line: line
        )
        .label

      if label != text {
        TestFailure
          .error(
            message:
              "Element \"\(identifier)\"\(identifier)\"\(specifier.map { " inside \"\($0)\" " } ?? "") text \"\(label)\" is not equal to \"\(text)\"!",
            file: file,
            line: line
          )
          .asTestFailure(
            file: file,
            line: line
          )
      }  // else passed
    }
    catch {
      error
        .asTestFailure(
          file: file,
          line: line
        )
    }
  }

  internal final func assert(
    _ identifier: String,
    inside specifier: String? = .none,
    textContains text: String,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      let label: String =
        try self.element(
          identifier,
          inside: specifier,
          timeout: timeout,
          file: file,
          line: line
        )
        .label

      if !label.contains(text) {
        TestFailure
          .error(
            message:
              "Element \"\(identifier)\"\(specifier.map { " inside \"\($0)\" " } ?? "") text \"\(label)\" does not contain \"\(text)\"!",
            file: file,
            line: line
          )
          .asTestFailure(
            file: file,
            line: line
          )
      }  // else passed
    }
    catch {
      error
        .asTestFailure(
          file: file,
          line: line
        )
    }
  }

  internal final func assertExists(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      try self.waitForElement(
        identifier,
        inside: specifier,
        timeout: timeout,
        file: file,
        line: line
      )
    }
    catch {
      error
        .asTestFailure(
          file: file,
          line: line
        )
    }
  }

  internal final func assertNotExists(
    _ identifier: String,
    inside specifier: String? = .none,
    // shorter default timeout, we expect it to not be there but still wan't to wait a while to be sure
    timeout: Double = 0.5,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      try self.waitForElement(
        identifier,
        inside: specifier,
        timeout: timeout,
        file: file,
        line: line
      )

      TestFailure
        .error(
          message: "Not expected element \"\(identifier)\"\(specifier.map { " inside \"\($0)\" " } ?? "") exists!",
          file: file,
          line: line
        )
        .asTestFailure(
          file: file,
          line: line
        )
    }
    catch {
      // not existing passes
    }
  }

  internal final func assertInteractive(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      let enabled: Bool =
        try self.element(
          identifier,
          inside: specifier,
          timeout: timeout,
          file: file,
          line: line
        )
        .isEnabled

      if !enabled {
        throw
          TestFailure
          .error(
            message:
              "Required element \"\(identifier)\"\(specifier.map { " inside \"\($0)\" " } ?? "") is not interactive!",
            file: file,
            line: line
          )
      }  // else passes
    }
    catch {
      error
        .asTestFailure(
          file: file,
          line: line
        )
    }
  }

  internal final func assertPresentsString(
    matching string: String,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let element: XCUIElement = self.application
      .descendants(matching: .staticText)
      .containing(
        NSPredicate(
          format: "label CONTAINS[c] %@",
          string
        )
      )
      .firstMatch

    let exists: Bool =
      element.exists
      ? true
      : element.waitForExistence(timeout: timeout)

    if !exists {
      TestFailure
        .error(
          message: "Required string \"\(string)\" does not exists!",
          file: file,
          line: line
        )
        .asTestFailure(
          file: file,
          line: line
        )
    }  // else passes
  }

  internal final func assertPresentsSafari(
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let safari = self.safari
    let exists: Bool =
      safari.exists
      ? true
      : safari.wait(for: .runningForeground, timeout: timeout)

    if !exists {
      throw
        SafariError
        .appLoadTimeout
    }
  }

  internal final func assertPresentsStringInSafari(
    matching string: String,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      let element: XCUIElement = self.safari
        .descendants(matching: .staticText)
        .containing(
          NSPredicate(
            format: "label CONTAINS[c] %@",
            string
          )
        )
        .firstMatch

      let exists: Bool =
        element.exists
        ? true
        : element.waitForExistence(timeout: timeout)

      if !exists {
        throw
          TestFailure
          .error(
            message: "Required string \"\(string)\" does not exists!",
            file: file,
            line: line
          )
      }
    }
    catch {
      error
        .asTestFailure(
          file: file,
          line: line
        )
    }  // else passes
  }

  internal final func ignoreFailure(
    _ reason: String,
    _ execute: () throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTExpectFailure(reason, options: .nonStrict()) {
      do {
        try execute()
      }
      catch {
        // ignore failures
      }
    }
  }

  enum SafariError: Error {
    case appLoadTimeout
  }
}
