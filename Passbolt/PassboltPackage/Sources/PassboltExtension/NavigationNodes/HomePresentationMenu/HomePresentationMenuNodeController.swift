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

  internal nonisolated let viewState: ViewStateVariable<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let navigationTree: NavigationTree
  private let homePresentation: HomePresentation

  internal init(
    context: Void,
    features: Features
  ) throws {

    self.asyncExecutor = try features.instance()
    self.navigationTree = features.instance()
    self.homePresentation = try features.instance()

    self.viewState = .init(
      initial: .init(
        currentMode: homePresentation.currentMode.wrappedValue,
        availableModes: homePresentation.availableModes()
      )
    )

    self.asyncExecutor.scheduleIteration(
      over: self.homePresentation.currentMode.asAnyAsyncSequence(),
      failMessage: "Home mode updates broken!"
    ) { [viewState] (mode: HomePresentationMode) in
      await viewState.update(\.currentMode, to: mode)
    }
  }
}

extension HomePresentationMenuNodeController {

  internal struct ViewState: Hashable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: OrderedSet<HomePresentationMode>
  }
}

extension HomePresentationMenuNodeController {

  internal final func selectMode(
    _ mode: HomePresentationMode
  ) {
    self.homePresentation.currentMode.set(to: mode)
    self.asyncExecutor.schedule(.reuse) { [viewState, navigationTree] in
      await navigationTree.dismiss(viewState.viewNodeID)
    }
  }

  internal nonisolated func dismissView() {
    self.asyncExecutor.schedule(.reuse) { [viewState, navigationTree] in
      await navigationTree.dismiss(viewState.viewNodeID)
    }
  }
}
