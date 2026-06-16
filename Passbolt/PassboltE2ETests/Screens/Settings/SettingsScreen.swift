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

final internal class SettingsScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      title
    ]
  }

  internal lazy var title: XCUIElement = self.application.staticTexts["Settings"].firstMatch

  internal lazy var appSettings: XCUIElement = self.application.buttons["settings.main.item.application.title"]
  internal lazy var accounts: XCUIElement = self.application.buttons["settings.main.item.accounts.title"]
  internal lazy var termsAndLicenses: XCUIElement = self.application.buttons["settings.main.item.terms.and.licenses.title"]
  internal lazy var logs: XCUIElement = self.application.buttons["Debug, logs"]
  internal lazy var signOut: XCUIElement = self.application.buttons["settings.main.item.sign.out.title"]
  internal lazy var confirmationAlert: XCUIElement = self.application.alerts.firstMatch
}

internal struct VerifySettingsEntry: UITestStep {

  internal var name: String { "Verifying \(title) settings entry" }

  private let title: String
  private let iconName: String
  private let hasDisclosureIndicator: Bool
  private let element: XCUIElement
  private let file: StaticString
  private let line: UInt

  internal init(
    title: String,
    iconName: String,
    hasDisclosureIndicator: Bool,
    with element: XCUIElement,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.title = title
    self.iconName = iconName
    self.hasDisclosureIndicator = hasDisclosureIndicator
    self.element = element
    self.file = file
    self.line = line
  }

  @MainActor
  internal func execute() throws {
    let icon: XCUIElement = element.images.firstMatch
    let title: XCUIElement = element.staticTexts.firstMatch

    if !icon.exists {
      throw ElementInvalid(
        elementName: "icon with name \(iconName)",
        file: file,
        line: line
      )
    }
    if !title.exists {
      throw ElementInvalid(
        elementName: "title with name \(title.label)",
        file: file,
        line: line
      )
    }
    if element.images["ChevronRight"].exists != hasDisclosureIndicator {
      throw ElementInvalid(
        elementName: "disclosure indicator",
        file: file,
        line: line
      )
    }
  }

  struct ElementInvalid: Error {

    private let elementName: String
    private let file: StaticString
    private let line: UInt

    fileprivate init(elementName: String, file: StaticString, line: UInt) {
      self.elementName = elementName
      self.file = file
      self.line = line
    }
  }
}
