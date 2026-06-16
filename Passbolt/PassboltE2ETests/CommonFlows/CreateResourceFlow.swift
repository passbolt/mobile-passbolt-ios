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

internal struct CreateResource: CombinedUITestStep {

  private let resourceName: ResourceName
  private let uri: String
  private let username: String
  private let password: String

  internal init(
    resourceName: ResourceName,
    uri: String = "",
    username: String = "",
    password: String = ""
  ) {
    self.resourceName = resourceName
    self.uri = uri
    self.username = username
    self.password = password
  }

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    On(AllResourcesListScreen.self) { screen in
      Tap(screen.createButton, "Create button")
      On(CreateResourceDrawerScreen.self) { drawer in
        Tap(drawer.passwordOption, "Create resource drawer password option")
      }
      On(ResourceEditScreen.self) { editScreen in
        TypeText(resourceName, into: editScreen.nameField, "Resource name")
          .dismissKeyboardIfNeeded()
        TypeText(uri, into: editScreen.mainURIField, "Resource URI")
          .dismissKeyboardIfNeeded()
        TypeText(username, into: editScreen.usernameField, "Resource username")
          .dismissKeyboardIfNeeded()
        TypeText(password, into: editScreen.passwordField, "Resource password")
          .dismissKeyboardIfNeeded()
        Tap(editScreen.saveButton, "Save resource")
        // long timeout as currently it refreshes entire session data
        WaitForDisappearance(editScreen.saveButton, timeout: .longNetworkCall, "Save button")
      }
    }
  }

  @MainActor
  private var cell: XCUIElement {
    application.cells.containing(.init(format: "label == %@",resourceName)).element
  }
}
