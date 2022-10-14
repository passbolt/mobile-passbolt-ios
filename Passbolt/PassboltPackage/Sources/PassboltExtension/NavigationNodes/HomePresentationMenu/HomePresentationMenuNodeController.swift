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

internal struct HomePresentationMenuNodeController {

  @IID internal var id
  @NavigationNodeID public var nodeID
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension HomePresentationMenuNodeController: ViewNodeController {

  internal struct ViewState: Hashable {

    @StateBinding internal var currentMode: HomePresentationMode
    internal var availableModes: OrderedSet<HomePresentationMode>
  }

  internal struct ViewActions: ViewControllerActions {

    internal var selectMode: (HomePresentationMode) -> Void
    internal var dismissView: () -> Void

    #if DEBUG
    internal static var placeholder: Self {
      .init(
        selectMode: { _ in unimplemented() },
        dismissView: { unimplemented() }
      )
    }
    #endif
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder
    )
  }
  #endif
}

// MARK: - Implementation

extension HomePresentationMenuNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let nodeID: NavigationNodeID = .init()
    let navigationTree: NavigationTree = features.instance()
    let homePresentation: HomePresentation = try await features.instance()

    let state: StateBinding<ViewState> =
      .variable(
        initial: .init(
          currentMode: homePresentation.currentMode,
          availableModes: homePresentation.availableModes()
        )
      )
    state.bind(\.$currentMode)

    let viewState: ViewStateBinding<ViewState> = .init(
      stateSource: state
    )

    nonisolated func selectMode(
      _ mode: HomePresentationMode
    ) {
      homePresentation.currentMode.set(to: mode)
      navigationTree.dismiss(nodeID)
    }

    nonisolated func dismissView() {
      navigationTree.dismiss(nodeID)
    }

    return .init(
      nodeID: nodeID,
      viewState: viewState,
      viewActions: .init(
        selectMode: selectMode(_:),
        dismissView: dismissView
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltHomePresentationMenuNodeController() {
    self.use(
      .disposable(
        HomePresentationMenuNodeController.self,
        load: HomePresentationMenuNodeController.load(features:)
      )
    )
  }
}
