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

internal struct SelectAllItemsFilter: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    // Skip the (redundant) filter switch when the list already shows the All items page.
    When(self.application.navigationBars["All items"].exists == false, "Not already on All items") {
      ClearSearchField()
      WaitFor(self.application.buttons["search.view.menu"], "Filter button")
      Tap(self.application.buttons["search.view.menu"], "Open filter")
      On(HomeFilterScreen.self) { filter in
        Tap(filter.allItemsButton, "Select All Items")
      }
    }
  }
}

internal struct SelectFoldersFilter: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    ClearSearchField()
    WaitFor(self.application.buttons["search.view.menu"], "Filter button")
    Tap(self.application.buttons["search.view.menu"], "Open filter")
    On(HomeFilterScreen.self) { filter in
      Tap(filter.foldersButton, "Select Folders")
    }
  }
}

/// Selects any filter from the home "Filter view by" drawer.
///
/// Generalizes `SelectAllItemsFilter` / `SelectFoldersFilter` over `HomeFilter`. The search field is
/// cleared first because the filter menu button is hidden while the field holds text or focus.
internal struct SelectFilter: CombinedUITestStep {

  internal let name: String
  private let filter: HomeFilter

  internal init(_ filter: HomeFilter) {
    self.name = "SelectFilter: \(filter.title)"
    self.filter = filter
  }

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    ClearSearchField()
    WaitFor(self.application.buttons["search.view.menu"], "Filter button")
    Tap(self.application.buttons["search.view.menu"], "Open filter")
    On(HomeFilterScreen.self) { drawer in
      // The drawer content scrolls and its trailing items start below the fold. Scrolling is
      // conditional so an already visible item is not scrolled out of view by the gesture.
      When(drawer.filterItem(self.filter).isHittable == false, "Filter is below the fold") {
        ScrollUntilVisible(drawer.filterItem(self.filter), "Scroll to \(self.filter.title)")
      }
      Tap(drawer.filterItem(self.filter), "Select \(self.filter.title)")
    }
  }
}

/// Opens the home "Filter view by" drawer without selecting anything.
internal struct OpenFilterDrawer: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    ClearSearchField()
    WaitFor(self.application.buttons["search.view.menu"], "Filter button")
    Tap(self.application.buttons["search.view.menu"], "Open filter")
  }
}
