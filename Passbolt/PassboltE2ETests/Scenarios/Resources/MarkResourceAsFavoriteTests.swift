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
final internal class MarkResourceAsFavoriteTests: UITestCase {

  /// Scenario:
  /// Given I am logged in as user
  /// And I have access to a resource
  /// When I mark the resource as a favorite
  /// Then a favorite icon appears on the top right corner of the main password icon
  ///
  /// A dedicated resource is created (and deleted at the end) so the test is isolated
  /// from other E2E tests that may run in parallel against the same backend.
  func test_markingResourceAsFavorite_showsFavoriteIconOnResourceDetails() async throws {
    let resource: ResourceTestData = .testResource
    let resourceName: String = "FavoriteTestiOS".withDateSuffix().withRandomSuffix()

    await executeSteps {
      Group("Create a dedicated resource") {
        SelectAllItemsFilter()
        CreateResource(
          resourceName: resourceName,
          uri: resource.mainURI,
          username: resource.username,
          password: resource.password
        )
        VerifySnackBarMessage(expectedMessage: "New password has been created")
      }

      Group("Mark the resource as a favorite") {
        OpenResourceListContextualMenu(resourceName: resourceName)
        On(ResourceContextMenuScreen.self) { screen in
          Tap(screen.addToFavoriteButton, "Add to favorite")
        }
        VerifySnackBarMessage(expectedMessage: "\(resourceName) has been added to favorites!")
      }

      Group("Verify the favorite icon is shown on the resource icon") {
        OpenResourceDetails(resourceName: resourceName)
        On(ResourceDetailsScreen.self) { screen in
          WaitFor(screen.favoriteIcon, timeout: .standardUI, "Wait for favorite icon")
          Verify(screen.favoriteIcon.exists, "Favorite icon appears on top right of the resource icon")
          Tap(screen.backButton, "Back to resource list")
        }
      }

      // Clean up the dedicated resource so repeated/parallel runs stay isolated.
      Group("Delete the dedicated resource") {
        DeleteResource(resourceName: resourceName)
      }
    }
  }
}
