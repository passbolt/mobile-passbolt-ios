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

@MainActor
final internal class EditResourceTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/8135
  func test_onTheEditPasswordPageICanEditElements() async throws {
    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetailsActionMenu(resourceName: ResourceTestData.editableResource.resourceName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        let editedName: String = ResourceTestData.editableResource.resourceName + "DeleteMe"
        TypeText(editedName, into: edit.nameField, "Edit name")
          .dismissKeyboardIfNeeded()
        VerifyValue(element: edit.nameField, expectedValue: editedName)

        ScrollUntilVisible(edit.mainURIField)
        let editedURI: String = ResourceTestData.editableResource.mainURI + "DeleteMe"
        TypeText(editedURI, into: edit.mainURIField, "Edit URI")
          .dismissKeyboardIfNeeded()
        VerifyValue(element: edit.mainURIField, expectedValue: editedURI)

        ScrollUntilVisible(edit.usernameField)
        let editedUsername: String = ResourceTestData.editableResource.username + "DeleteMe"
        TypeText(editedUsername, into: edit.usernameField, "Edit username")
          .dismissKeyboardIfNeeded()
        VerifyValue(element: edit.usernameField, expectedValue: editedUsername)
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8136
  func test_onTheEditPasswordPageICanSaveChangedResources() async throws {
    let randomName: String = "iOSTestResource".withDateSuffix().withRandomSuffix()
    let updatedName: String = "Updated".withDateSuffix().withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(
        resourceName: randomName,
        uri: ResourceTestData.testResource.mainURI,
        username: ResourceTestData.testResource.username,
        password: ResourceTestData.testResource.password
      )
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetailsActionMenu(resourceName: randomName)
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.editButton, "Edit")
      }
      On(ResourceEditScreen.self) { edit in
        ReplaceText(updatedName, in: edit.nameField, "Edit name")
          .dismissKeyboardIfNeeded()
        ReplaceText("DeleteMe", in: edit.mainURIField, "Edit URI")
          .dismissKeyboardIfNeeded()
        ReplaceText("DeleteMe", in: edit.usernameField, "Edit username")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save")
      }
      WaitFor(application.staticTexts[updatedName], timeout: .slowNetworkCall, "Resource name updated")
      Verify(application.staticTexts[updatedName].exists, "Updated name visible")
    }
  }
}


struct VerifyValue<T: Equatable>: UITestStep {

  private let element: XCUIElement
  private let expectedValue: T
  private let file: StaticString
  private let line: UInt

  internal init(element: XCUIElement, expectedValue: T, file: StaticString = #fileID, line: UInt = #line) {
    self.element = element
    self.expectedValue = expectedValue
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    guard let value = element.value as? T else {
      throw InvalidValueType(
        "Expected \(T.self), got: \(type(of: element.value))",
        file: file,
        line: line
      )
    }
    XCTAssertTrue(value == expectedValue, "Expected \(expectedValue), got: \(value)", file: file, line: line)
  }

  internal struct InvalidValueType: Error {

    let file: StaticString
    let line: UInt
    let message: String

    init(_ message: String, file: StaticString, line: UInt) {
      self.file = file
      self.line = line
      self.message = message
    }
  }
}

internal struct ReplaceText: UITestStep {

  internal let name: String
  private let text: String
  private let element: XCUIElement
  private let file: StaticString
  private let line: UInt

  internal init(
    _ text: String,
    in element: XCUIElement,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description ?? "ReplaceText"
    self.text = text
    self.element = element
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    try ensureExists(element, file: file, line: line)
    guard text.isEmpty == false else { return }
    self.element.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    self.element.typeText(XCUIKeyboardKey.delete.rawValue)
    try
      TypeText(text, into: element, name)
      .execute()
  }
}
