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

final internal class TOTPListScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      header,
      createButton
    ]
  }

  internal lazy var otpIcon: XCUIElement = self.application.images["OTP"]
  internal lazy var header: XCUIElement = self.application.staticTexts["TOTP"]
  internal lazy var createButton: XCUIElement = self.application.buttons["totp_list_create_button"]
  internal lazy var searchField: XCUIElement = self.application.textFields["search.view.input"]
  internal lazy var collectionView: XCUIElement = self.application.collectionViews["totp.collection.view"]
  internal lazy var totpTab: XCUIElement = self.application.tabBars.firstMatch.buttons["TOTP"]
  internal lazy var clearSearchFieldButton: XCUIElement = self.application.buttons["Close"]

  // MARK: - Collection view elements

  internal lazy var obfuscationMarker: XCUIElement = self.application.staticTexts["••• •••"]
  internal lazy var eyeIcon: XCUIElement = self.application.images["Eye"]
  internal lazy var moreButton: XCUIElement = self.application.buttons["More"]
  internal lazy var totpDigits: XCUIElement = self.application.staticTexts["totp.digits"]
  internal lazy var timerCircle: XCUIElement = self.application.otherElements["totp.loader.circle"]

  internal func totpResourceIcon(identifier: String) -> XCUIElement {
    self.application.images[identifier]
  }
}

internal struct OpenTOTPContextualMenu: CombinedUITestStep {

  internal let name: String

  internal init(name: String) {
    self.name = name
  }

  @UITestStepsBuilder
  internal var steps: Array<UITestStep> {
    TypeText(name, into: application.textFields["search.view.input"], "Search for resource \(name)")
    Tap(moreButton)
  }

  @MainActor
    private var moreButton: XCUIElement {
      application.buttons.containing(
        .init(
          format: "identifier = %@ AND label = %@", "totp_list_resource_" + name, "More")
      ).element
    }
}
