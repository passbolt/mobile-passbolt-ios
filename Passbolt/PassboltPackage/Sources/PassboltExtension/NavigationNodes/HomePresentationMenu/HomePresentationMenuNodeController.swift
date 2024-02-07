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

import Display
import OSFeatures

internal final class HomePresentationMenuNodeController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let navigationTree: NavigationTree
  private let homePresentation: HomePresentation

  private let context: ViewNodeID

  internal init(
    context: ViewNodeID,
    features: Features
  ) throws {
    self.context = context

    self.navigationTree = features.instance()
    self.homePresentation = try features.instance()

    self.viewState = .init(
      initial: .init(
        currentMode: homePresentation.currentMode.wrappedValue,
        availableModes: homePresentation.availableModes()
      ),
      updateFrom: self.homePresentation.currentMode.updates,
      update: { [homePresentation] (updateState, _) in
        await updateState { (state: inout ViewState) in
          state.currentMode = homePresentation.currentMode.get()
        }
      }
    )
  }
}

extension HomePresentationMenuNodeController {

  internal struct ViewState: Equatable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: OrderedSet<HomePresentationMode>
  }
}

extension HomePresentationMenuNodeController {

  internal func selectMode(
    _ mode: HomePresentationMode
  ) {
    self.homePresentation.currentMode.set(to: mode)
    self.navigationTree.dismiss(upTo: self.context)
  }

  internal func dismissView() {
    self.navigationTree.dismiss(self.viewNodeID)
  }
}
