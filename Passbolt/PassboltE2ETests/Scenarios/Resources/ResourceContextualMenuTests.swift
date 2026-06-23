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
/// https://passbolt.testrail.io/index.php?/cases/view/2383
final internal class ResourceContextualMenuTests: UITestCase {

  func test_resourceContextualMenu_ofSimplePassword() async throws {
    let resource: ResourceTestData = .simplePasswordV4

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceListContextualMenu(resourceName: resource.resourceName)
      On(ResourceContextMenuScreen.self) { screen in
        Verify(screen.copyURLButton.exists, "Copy URL exists")
        Verify(screen.copyUsernameButton.exists, "Copy username exists")
        Verify(screen.copyPasswordButton.exists, "Copy password exists")
        Verify(screen.copyDescriptionButton.exists, "Copy description exists")
        Verify(!screen.copyNoteButton.exists, "Copy note does not exist")
      }
    }
  }

  func test_resourceContextualMenu_ofDefaultResource() async throws {
    let resource: ResourceTestData = .defaultResourceType

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceListContextualMenu(resourceName: resource.resourceName)
      On(ResourceContextMenuScreen.self) { screen in
        Verify(screen.copyURLButton.exists, "Copy URL exists")
        Verify(screen.copyUsernameButton.exists, "Copy username exists")
        Verify(screen.copyPasswordButton.exists, "Copy password exists")
        Verify(screen.copyDescriptionButton.exists, "Copy description exists")
        Verify(screen.copyNoteButton.exists, "Copy note exists")
      }
    }
  }

  func test_resourceContextualMenu_ofPasswordDescriptionAnNote() async throws {
    let resource: ResourceTestData = .passwordDescriptonNote

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceListContextualMenu(resourceName: resource.resourceName)
      On(ResourceContextMenuScreen.self) { screen in
        Verify(screen.copyURLButton.exists, "Copy URL does exist")
        Verify(screen.copyUsernameButton.exists, "Copy username does exist")
        Verify(screen.copyPasswordButton.exists, "Copy password does exist")
        Verify(screen.copyDescriptionButton.exists, "Copy description exists")
        Verify(screen.copyNoteButton.exists, "Copy note exists")
      }
    }
  }
}
