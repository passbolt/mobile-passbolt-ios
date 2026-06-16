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

internal struct With<Element: UIElement>: UITestStep {

  private let steps: (Element) -> Array<UITestStep>
  private let element: XCUIElement
  private let mappedElementType: Element.Type
  private let file: StaticString
  private let line: UInt

  /// Map an `XCUIElement` to a custom `UIElement` type and execute the steps with the mapped element.
  /// - Parameters:
  /// - `element`: The `XCUIElement` to map and use for the steps.
  /// - `mappedElement`: The type of the custom `UIElement` to map to
  /// - `builder`: A builder that returns the steps with element.
  internal init(
    _ element: XCUIElement,
    as mappedElement: Element.Type,
    @UITestStepsBuilder _ builder: @escaping (Element) -> Array<UITestStep>,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.element = element
    self.mappedElementType = mappedElement
    self.steps = builder
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    guard let mappedElement = mappedElementType.init(element) else {
      throw MappingFailure(targetType: mappedElementType, file: file, line: line)
    }
    for step in self.steps(mappedElement) {
      try XCTContext.runActivity(named: step.name) { _ in
        try step.execute()
      }
    }
  }
}
