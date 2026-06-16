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
final internal class DeleteResourceTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/8140
  func test_onTheActionMenuDrawerICanClickDeletePasswordElement() async throws {
    let application: XCUIApplication = await self.application

    await executeSteps {
      OpenResourceDetailsActionMenu(resourceName: application.firstResourceName())
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.deleteButton, "Delete password")
          .scrollIfNeeded()
      }
      With(application.alerts.firstMatch, as: Alert.self) { alert in
        Verify(alert.title == "Are you sure?", "Alert title")
        Verify(alert.buttons["Cancel"]?.exists == true, "Cancel button exists")
        Verify(alert.buttons["Delete"]?.exists == true, "Delete button exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8141
  func test_onThePasswordRemovalPopupICanClickTheCancelButton() async throws {
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetailsActionMenu(resourceName: application.firstResourceName())
      On(ResourceDetailsActionMenuScreen.self) { menu in
        Tap(menu.deleteButton, "Delete password")
      }
      With(application.alerts.firstMatch, as: Alert.self) { alert in
        if let cancelButton = alert.buttons["Cancel"], cancelButton.exists {
          Tap(cancelButton, "Cancel")
        }
      }
      On(ResourceDetailsScreen.self) { details in
        Verify(details.title.exists, "Back on resource details")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8142
  func test_onThePasswordRemovalPopupICanClickTheDeleteButton() async throws {
    let randomName: String = ResourceTestData.testResource.resourceName.withRandomSuffix()
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
        Tap(menu.deleteButton, "Delete password")
      }
      With(application.alerts.firstMatch, as: Alert.self) { alert in
        Tap(alert.buttons["Delete"], "Confirm delete")
      }
      VerifySnackBarMessage(expectedMessage: "Resource has been deleted")
      WaitForDisappearance(application.staticTexts[randomName], timeout: .networkCall, "Deleted resource to disappear")
    }
  }
}

extension XCUIApplication {

  fileprivate func firstResourceName() -> String {
    let prefix: String = "resources_list_resource_"
    let predicate: NSPredicate = .init(format: "identifier BEGINSWITH %@", prefix)
    let firstResourceCell: XCUIElement = self.buttons.matching(predicate).firstMatch
    let expectation: XCTNSPredicateExpectation = .init(predicate: predicate, object: firstResourceCell)
    _ = XCTWaiter().wait(for: [expectation], timeout: .networkCall)
    return firstResourceCell.identifier.replacingOccurrences(of: prefix, with: "")
  }
}
