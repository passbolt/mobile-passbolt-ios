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

  // MARK: Initialization

  internal final lazy var application: XCUIApplication = {
    let application: XCUIApplication = .init()
    self.applicationSetup(application: application)
    application.launch()
    return application
  }()

  internal func applicationSetup(
    application: XCUIApplication
  ) {
    // to be overriden
  }

  // MARK: Device

  internal final func rotateDevice(
    _ orientation: UIDeviceOrientation
  ) {
    XCUIDevice.shared.orientation = orientation
  }

  // MARK: Test support

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

  internal final func element(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) -> XCUIElement {
    let element: XCUIElement = self.application
      .descendants(matching: .any)
      .element(
        matching: .any,
        identifier: identifier
      )
    XCTAssertTrue(
      element.exists,
      "\(identifier) does not exist.",
      file: file,
      line: line
    )
    return element
  }

  // MARK: Interactions

  internal func tap(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.element(
      identifier,
      file: file,
      line: line
    )
    .tap()
  }

  internal func swipeUp(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.element(
      identifier,
      file: file,
      line: line
    )
    .swipeUp()
  }

  internal func swipeDown(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.element(
      identifier,
      file: file,
      line: line
    )
    .swipeUp()
  }

  internal func typeTo(
    _ identifier: String,
    text value: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    self.element(
      identifier,
      file: file,
      line: line
    )
    .typeText(value)
  }

  // MARK: Verify

  internal func assert(
    _ identifier: String,
    textMatches text: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let label: String = self.element(
        identifier,
        file: file,
        line: line
      )
      .label
    XCTAssertEqual(
      label,
      text,
      "\(identifier) text (\(label)) does not match expected (\(text)).",
      file: file,
      line: line
    )
  }

  internal func assertExists(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    _ = self.element(
      identifier,
      file: file,
      line: line
    )
  }

  internal func assertInteractive(
    _ identifier: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let enabled: Bool = self.element(
        identifier,
        file: file,
        line: line
      )
      .isEnabled
    XCTAssertTrue(
      enabled,
      "\(identifier) is not interactive.",
      file: file,
      line: line
    )
  }

  internal func assertPresentsString(
    matching string: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let exists: Bool = self.application
      .descendants(matching: .staticText)
      .containing(
        NSPredicate(
          format: "label CONTAINS[c] %@",
          string
        )
      )
      .count > 0

    XCTAssertTrue(
      exists,
      "String (\(string)) is not presented.",
      file: file,
      line: line
    )
  }
}
