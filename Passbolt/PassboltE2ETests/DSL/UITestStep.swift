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

internal protocol UITestStep: ApplicationAccessor {

  var name: String { get }
  @MainActor func execute() throws

}

extension UITestStep {
  var name: String {
    String(describing: Self.self)
  }

  @MainActor
  func ensureExists(_ element: XCUIElement, file: StaticString, line: UInt) throws {
    if !element.exists {
      throw ElementMissing(
        "Expected element to exist, but it does not.",
        file: file,
        line: line
      )
    }
  }
}

@resultBuilder
internal enum UITestStepsBuilder {

  static func buildExpression(_ step: UITestStep) -> Array<UITestStep> {
    [step]
  }

  static func buildExpression(_ steps: Array<UITestStep>) -> Array<UITestStep> {
    steps
  }

  static func buildBlock(_ components: Array<UITestStep>...) -> Array<UITestStep> {
    components.flatMap { $0 }
  }

  static func buildOptional(_ component: Array<UITestStep>?) -> Array<UITestStep> {
    component ?? []
  }

  static func buildEither(first component: Array<UITestStep>) -> Array<UITestStep> {
    component
  }

  static func buildEither(second component: Array<UITestStep>) -> Array<UITestStep> {
    component
  }

  static func buildArray(_ components: Array<Array<UITestStep>>) -> Array<UITestStep> {
    components.flatMap { $0 }
  }
}
