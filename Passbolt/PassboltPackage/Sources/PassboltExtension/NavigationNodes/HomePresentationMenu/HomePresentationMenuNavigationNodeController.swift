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

// MARK: - Interface

internal struct HomePresentationMenuNavigationNodeController {

  internal var displayViewState: DisplayViewState<ViewState>
  internal var selectMode: (HomePresentationMode, NavigationNodeID) -> Void
  internal var dismissView: (NavigationNodeID) -> Void
}

extension HomePresentationMenuNavigationNodeController: ContextlessNavigationNodeController {

  internal struct ViewState: Hashable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: OrderedSet<HomePresentationMode>
  }

#if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      displayViewState: .placeholder,
      selectMode: unimplemented(),
      dismissView: unimplemented()
    )
  }
#endif
}

// MARK: - Implementation

extension HomePresentationMenuNavigationNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let navigationTree: NavigationTree = features.instance()
    let homePresentation: HomePresentation = try await features.instance()

    let viewState: DisplayViewState<ViewState> = .init(
      initial: .init(
        currentMode: homePresentation.currentMode.wrappedValue,
        availableModes: homePresentation.availableModes()
      )
    )

    nonisolated func selectMode(
      _ mode: HomePresentationMode,
      dismiss nodeID: NavigationNodeID
    ) {
      homePresentation.currentMode.set(\.self, mode)
      navigationTree.dismiss(nodeID)
    }

    nonisolated func dismissView(
      _ nodeID: NavigationNodeID
    ) {
      navigationTree.dismiss(nodeID)
    }

    return .init(
      displayViewState: viewState,
      selectMode: selectMode(_:dismiss:),
      dismissView: dismissView
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltHomePresentationMenuNavigationNodeController() {
    self.use(
      .disposable(
        HomePresentationMenuNavigationNodeController.self,
        load: HomePresentationMenuNavigationNodeController.load(features:)
      )
    )
  }
}
