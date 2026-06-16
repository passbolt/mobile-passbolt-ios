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
final internal class TOTPDrawerTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/9181
  func test_totpResourceDrawerMenuItems() async throws {
    let totp: TOTPTestData = .standaloneTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectTOTPTab()
      OpenTOTPDrawer(for: totp.resourceName)
      On(TOTPDrawerScreen.self) { drawer in
        Verify(drawer.closeButton.exists, "Close button")
        Verify(application.staticTexts[totp.resourceName].exists, "Resource name")
        Verify(drawer.copyTOTP.exists, "Copy TOTP")
        Verify(drawer.copyIcon.exists, "Copy icon")
        Verify(drawer.showTOTP.exists, "Show TOTP")
        Verify(drawer.eyeIcon.exists, "Eye icon")
        Verify(drawer.editTOTP.exists, "Edit TOTP")
        Verify(drawer.editIcon.exists, "Edit icon")
        Verify(drawer.deleteTOTP.exists, "Delete TOTP")
        Verify(drawer.trashIcon.exists, "Trash icon")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/9190
  func test_canDeleteTOTP() async throws {
    let randomName: String = "Delete me ".withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectTOTPTab()
      CreateTOTP(named: randomName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenTOTPDrawer(for: randomName)
      On(TOTPDrawerScreen.self) { drawer in
        Tap(drawer.deleteTOTP, "Delete TOTP")
      }
      With(application.alerts.firstMatch, as: Alert.self) { alert in
        Tap(alert.buttons["Delete TOTP"]!, "Confirm delete")
      }
      On(TOTPListScreen.self) { screen in
        WaitFor(application.staticTexts[randomName], predicate: "exists == false", timeout: .longNetworkCall, "Deleted TOTP not present")
      }
    }
  }
}

// MARK: - Helper Steps

internal struct OpenTOTPDrawer: CombinedUITestStep {

  private let resourceName: ResourceName

  internal init(for resourceName: ResourceName) {
    self.resourceName = resourceName
  }

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    On(TOTPListScreen.self, timeout: .networkCall) { screen in
      WaitFor(screen.createButton, "Ensure displayed")
      TypeText(self.resourceName, into: screen.searchField, "Search for resource")
      WaitFor(
        cell,
        timeout: .longNetworkCall,
        "Wait for cell to appear"
      )
      Tap(
        moreButton,
        "Tap on resource menu"
      )
    }
  }

  @MainActor
  private var cell: XCUIElement {
    application.buttons.containing(.init(format: "identifier = %@", "totp_list_resource_" + resourceName)).element
  }

  @MainActor
  private var moreButton: XCUIElement {
    application.buttons.containing(
      .init(
        format: "identifier = %@ AND label = %@", "totp_list_resource_" + resourceName, "More"
      )
    ).element
  }
}

struct Breakpoint: UITestStep {

  @MainActor internal func execute() throws {
    #if DEBUG
    raise(SIGTRAP)
    #endif
  }
}

struct Debug: UITestStep {

  private let step: UITestStep
  private let stopBefore: Bool
  private let stopAfter: Bool

  internal init(_ step: UITestStep, stopBefore: Bool, stopAfter: Bool) {
    self.step = step
    self.stopBefore = stopBefore
    self.stopAfter = stopAfter
  }

  @MainActor internal func execute() throws {
    if stopBefore {
      #if DEBUG
      raise(SIGTRAP)
      #endif
    }
    try step.execute()
    if stopAfter {
      #if DEBUG
      raise(SIGTRAP)
      #endif
    }
  }
}

extension UITestStep {

  internal func debug(stopBefore: Bool = true, stopAfter: Bool = true) -> some UITestStep {
    Debug(self, stopBefore: stopBefore, stopAfter: stopAfter)
  }
}
