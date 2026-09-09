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

/// Scenarios covering resource filtering on the home screen - both the "Filter view by" drawer
/// (presentation modes) and the search field applied on top of the selected mode.
@MainActor
final internal class HomeFilterTests: UITestCase {

  func test_asALoggedInUserICanSeeTheAvailableFiltersInTheDrawer() async throws {
    await executeSteps {
      OpenFilterDrawer()
      On(HomeFilterScreen.self) { drawer in
        VerifyEqual(drawer.header.label, "Filter view by", "Drawer header")
        Verify(drawer.closeButton.isHittable, "Close button is hittable")
        for filter: HomeFilter in HomeFilter.resourceLists {
          Verify(drawer.filterItem(filter).isHittable, "\(filter.title) filter is hittable")
          VerifyEqual(drawer.filterItem(filter).label, filter.title, "\(filter.title) filter label")
        }
        // The drawer content scrolls, and the trailing items sit below the fold - they exist in the
        // hierarchy but are not hittable until scrolled into view.
        ScrollUntilVisible(drawer.filterItem(.groups), "Scroll to the last filter")
        // Folders depend on the server configuration, but the automation backend has them enabled -
        // other suites (see `FolderCreationTests`) rely on the same. Tags are left out because no
        // suite establishes whether they are enabled.
        Verify(drawer.filterItem(.folders).exists, "Folders filter is listed")
        Verify(drawer.filterItem(.groups).isHittable, "Groups filter is hittable")
      }
    }
  }

  func test_asALoggedInUserICanSwitchBetweenTheResourceFilters() async throws {
    await executeSteps {
      for filter: HomeFilter in HomeFilter.resourceLists {
        Group("Switch to \(filter.title)") {
          SelectFilter(filter)
          On(HomeListScreen.self) { home in
            WaitFor(
              home.navigationBar(of: filter),
              timeout: .networkCall,
              "\(filter.title) list is displayed"
            )
            WaitForRefreshToComplete(home.list)
          }
        }
      }
    }
  }

  func test_asALoggedInUserICanCloseTheFilterDrawerWithoutChangingTheFilter() async throws {
    await executeSteps {
      SelectFilter(.allItems)
      OpenFilterDrawer()
      On(HomeFilterScreen.self) { drawer in
        Tap(drawer.closeButton, "Close the filter drawer")
      }
      On(HomeListScreen.self) { home in
        WaitFor(home.navigationBar(of: .allItems), "All items list is still displayed")
        Verify(home.filterButton.isHittable, "Filter button is available again")
      }
    }
  }

  func test_asALoggedInUserICanSwitchToTheFoldersFilter() async throws {
    await executeSteps {
      SelectFilter(.folders)
      On(FoldersScreen.self, timeout: .networkCall) { folders in
        Verify(folders.createButton.isHittable, "Folders explorer is displayed")
      }
      SelectFilter(.allItems)
      On(HomeListScreen.self) { home in
        WaitFor(home.navigationBar(of: .allItems), "Back on the All items list")
      }
    }
  }

  func test_asALoggedInUserICanFilterTheListByTypingAResourceName() async throws {
    let resource: ResourceTestData = .simplePasswordV4
    await executeSteps {
      SelectFilter(.allItems)
      On(HomeListScreen.self) { home in
        WaitForRefreshToComplete(home.list)
        TypeText(resource.resourceName, into: home.searchField, "Search for the resource")
        WaitFor(
          home.resourceCell(named: resource.resourceName),
          timeout: .longNetworkCall,
          "Matching resource is listed"
        )
      }
      ClearSearchField()
    }
  }

  func test_asALoggedInUserISeeNoResultsWhenNothingMatchesTheSearch() async throws {
    let unmatchableQuery: String = "NoSuchResource".withRandomSuffix()
    await executeSteps {
      SelectFilter(.allItems)
      On(HomeListScreen.self) { home in
        WaitForRefreshToComplete(home.list)
        TypeText(unmatchableQuery, into: home.searchField, "Search for a name no resource has")
        WaitFor(home.emptyListMessage, timeout: .networkCall, "Empty results placeholder is displayed")
      }
      Group("Clearing the search restores the list") {
        ClearSearchField()
        On(HomeListScreen.self) { home in
          WaitForDisappearance(home.emptyListMessage, "Empty results placeholder is gone")
          // The unfiltered list is asserted by cell count rather than by a named resource - which
          // resource sits within the rendered window depends on the device and the backend content.
          Verify(home.list.buttons.count > 0, "Resources are listed again")
        }
      }
    }
  }

  /// Covers the filter actually filtering resources rather than only retitling the list: a dedicated
  /// resource is created, marked as a favorite, and then looked up under the Favorites filter.
  /// It is unmarked and deleted at the end so repeated and parallel runs stay isolated.
  func test_asALoggedInUserISeeMyFavoriteResourceUnderTheFavoritesFilter() async throws {
    let resource: ResourceTestData = .testResource
    let resourceName: String = "FilterFavoriteTestiOS".withDateSuffix().withRandomSuffix()

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
        On(ResourceContextMenuScreen.self) { menu in
          Tap(menu.addToFavoriteButton, "Add to favorite")
        }
        VerifySnackBarMessage(expectedMessage: "\(resourceName) has been added to favorites!")
      }

      Group("The resource is listed under the Favorites filter") {
        SelectFilter(.favorites)
        On(HomeListScreen.self) { home in
          WaitFor(home.navigationBar(of: .favorites), timeout: .networkCall, "Favorites list is displayed")
          WaitForRefreshToComplete(home.list)
          WaitFor(
            home.resourceCell(named: resourceName),
            timeout: .longNetworkCall,
            "Favorite resource is listed"
          )
        }
      }

      Group("Unmarking the resource removes it from the Favorites filter") {
        // The contextual menu is opened from the All items list - `OpenResourceListContextualMenu`
        // waits for that screen by its navigation bar title.
        SelectFilter(.allItems)
        OpenResourceListContextualMenu(resourceName: resourceName)
        On(ResourceContextMenuScreen.self) { menu in
          Tap(menu.removeFromFavoriteButton, "Remove from favorite")
        }
        VerifySnackBarMessage(expectedMessage: "\(resourceName) has been removed from favorites!")
        SelectFilter(.favorites)
        On(HomeListScreen.self) { home in
          WaitForRefreshToComplete(home.list)
          WaitForDisappearance(
            home.resourceCell(named: resourceName),
            timeout: .longNetworkCall,
            "Unmarked resource is no longer listed"
          )
        }
      }

      Group("Delete the dedicated resource") {
        SelectAllItemsFilter()
        DeleteResource(resourceName: resourceName)
      }
    }
  }
}
