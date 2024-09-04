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
    let collectionView = try element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )

    guard collectionView.exists else {
      throw TestFailure.error(
        message: "Collection view \"\(identifier)\" not found!",
        file: file,
        line: line
      )
    }

    let cells = collectionView.children(matching: .cell)
    guard cells.count > index else {
      throw TestFailure.error(
        message: "Cell at index \(index) not found in collection view \"\(identifier)\"!",
        file: file,
        line: line
      )
    }

    let cell = cells.element(boundBy: index)
    guard cell.waitForExistence(timeout: timeout) else {
      throw TestFailure.error(
        message: "Cell at index \(index) not found or not hittable!",
        file: file,
        line: line
      )
    }

    cell.tap()
  }

  internal final func selectCollectionViewButton(
    identifier: String,  // The identifier of the collection view itself.
    inside specifier: String? = .none,  // An optional identifier of a parent element containing the collection view.
    buttonIdentifier: String,
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
    .element(boundBy: index)
    .buttons[buttonIdentifier]
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
    timeout: Double = 6.0,
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

  /**
     Taps a button inside a specific container.
     Use this when elements aren't directly accessible without specifying `containerIndex` like when you get `multiple matching elements found for <XCUIElementQuery: >`
     */
  internal final func tapButton(
    _ identifier: String,
    containerIndex: Int = 1,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let upgradeButtonContainer = self.application
      .descendants(matching: .any)
      .containing(.button, identifier: identifier)
      .element(boundBy: containerIndex)

    let exists: Bool =
      upgradeButtonContainer.exists
      ? true
      : upgradeButtonContainer.waitForExistence(timeout: timeout)

    if !exists {
      throw
        TestFailure
        .error(
          message: "Required element \"\(upgradeButtonContainer)\" does not exists!",
          file: file,
          line: line
        )
    }
    else {
      upgradeButtonContainer
        .buttons[identifier]
        .tap()
    }
  }

  internal final func swipeUp(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: Double = 2.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    let element = try self.element(
      identifier,
      inside: specifier,
      timeout: timeout,
      file: file,
      line: line
    )
    element.swipeUp()
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

  /*!
     * When testing in the XCode Cloud the driver is skipping some letters from the password
     * It forces us to use copy-paste method when filling the secureTextField
     */
  internal final func typePassphrase(
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
    UIPasteboard.general.string = value
    element.tap()  // to gain focus
    element.doubleTap()  // to trigger text menu

    let pasteMenuItem = XCUIApplication().menuItems.element(boundBy: 0)
    let menuExists: Bool =
      pasteMenuItem.exists
      ? true
      : pasteMenuItem.waitForExistence(timeout: timeout)
    if !menuExists {
      throw TestFailure.error(
        message: "Paste menu did not appear after attempting to double-tap the element \"\(identifier)\"",
        file: file,
        line: line
      )
    }
    pasteMenuItem.tap()
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
    timeout: Double = 3.0,
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
    timeout: Double = 3.0,
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

  internal final func assertExistsWithPattern(
    _ identifier: String,
    pattern: String = "\\d{3} \\d{3}",
    inside specifier: String? = .none,
    timeout: TimeInterval = 4.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let element = self.application
      .descendants(matching: .any)
      .element(
        matching: .any,
        identifier: identifier
      )

    let exists = element.waitForExistence(timeout: timeout)

    if !exists {
      XCTFail(
        "Required element \"\(identifier)\" inside \"\(String(describing: specifier))\" does not exist!",
        file: file,
        line: line
      )
      return
    }

    let predicate = NSPredicate(format: "label MATCHES %@", pattern)

    let success =
      XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
      == .completed

    if !success {
      XCTFail(
        "Element \"\(identifier)\" does not match the pattern \"\(pattern)\" within the timeout period!",
        file: file,
        line: line
      )
    }
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
