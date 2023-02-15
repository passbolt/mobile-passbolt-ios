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

// MARK: - Interface

internal struct HomePresentationMenuNodeController {

  internal var viewState: MutableViewState<ViewState>
  internal var selectMode: (HomePresentationMode) -> Void
  internal var dismissView: () -> Void
}

extension HomePresentationMenuNodeController: ViewController {

  internal struct ViewState: Hashable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: OrderedSet<HomePresentationMode>
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      selectMode: { _ in unimplemented() },
      dismissView: { unimplemented() }
    )
  }
  #endif
}

// MARK: - Implementation

extension HomePresentationMenuNodeController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigationTree: NavigationTree = features.instance()
    let homePresentation: HomePresentation = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        currentMode: homePresentation.currentMode.wrappedValue,
        availableModes: homePresentation.availableModes()
      )
    )
    viewState.cancellables.addCleanup(asyncExecutor.cancelTasks)

    homePresentation
      .currentMode
      .sink { (mode: HomePresentationMode) in
        viewState.update(\.currentMode, to: mode)
      }
      .store(in: viewState.cancellables)

    nonisolated func selectMode(
      _ mode: HomePresentationMode
    ) {
      homePresentation.currentMode.set(to: mode)
      asyncExecutor.schedule(.reuse) {
        await navigationTree.dismiss(viewState.viewNodeID)
      }
    }

    nonisolated func dismissView() {
      asyncExecutor.schedule(.reuse) {
        await navigationTree.dismiss(viewState.viewNodeID)
      }
    }

    return .init(
      viewState: viewState,
      selectMode: selectMode(_:),
      dismissView: dismissView
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltHomePresentationMenuNodeController() {
    self.use(
      .disposable(
        HomePresentationMenuNodeController.self,
        load: HomePresentationMenuNodeController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
