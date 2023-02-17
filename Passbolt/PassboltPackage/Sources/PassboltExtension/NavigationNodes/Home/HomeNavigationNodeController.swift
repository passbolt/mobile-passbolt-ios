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
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal struct HomeNavigationNodeController {

  internal var viewState: MutableViewState<ViewState>
  internal var activate: @Sendable () async -> Void
}

extension HomeNavigationNodeController: ViewController {

  internal typealias Context = SessionScope.Context

  internal struct ViewState: Hashable {

    internal var contentController: any ViewController

    public static func == (
      _ lhs: ViewState,
      _ rhs: ViewState
    ) -> Bool {
      lhs.contentController.equal(to: rhs.contentController)
    }

    internal func hash(
      into hasher: inout Hasher
    ) {
      hasher.combine(self.contentController)
    }
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      activate: unimplemented0()
    )
  }
  #endif
}

extension HomeNavigationNodeController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let features: Features =
      features
      .branch(
        scope: SessionScope.self,
        context: context
      )
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigationTree: NavigationTree = features.instance()
    let homePresentation: HomePresentation = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        contentController: contentRoot(
          for: homePresentation.currentMode.get()
        )
      )
    )

    @Sendable nonisolated func activate() async {
      asyncExecutor.schedule(.reuse) {
        await homePresentation
          .currentMode
          .asAnyAsyncSequence()
          .forEach { (mode: HomePresentationMode) in
            let contentController = await contentRoot(for: mode)
            await viewState.update { viewState in
              viewState.contentController = contentController
            }
            await navigationTree.dismiss(upTo: viewState.viewNodeID)
          }
      }
    }

    @MainActor func contentRoot(
      for mode: HomePresentationMode
    ) -> any ViewController {
      do {
        switch mode {
        case .plainResourcesList:
          return
            try features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName,
                baseFilter: .init(
                  sorting: .nameAlphabetically
                )
              )
            )

        case .modifiedResourcesList:
          return
            try features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName,
                baseFilter: .init(
                  sorting: .modifiedRecently
                )
              )
            )

        case .favoriteResourcesList:
          return
            try features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName,
                baseFilter: .init(
                  sorting: .nameAlphabetically,
                  favoriteOnly: true
                )
              )
            )

        case .sharedResourcesList:
          return
            try features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName,
                baseFilter: .init(
                  sorting: .nameAlphabetically,
                  permissions: [.read, .write]
                )
              )
            )

        case .ownedResourcesList:
          return
            try features
            .instance(
              of: ResourcesListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName,
                baseFilter: .init(
                  sorting: .nameAlphabetically,
                  permissions: [.owner]
                )
              )
            )

        case .tagsExplorer:
          return
            try features
            .instance(
              of: ResourceTagsListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName
              )
            )

        case .resourceUserGroupsExplorer:
          return
            try features
            .instance(
              of: ResourceUserGroupsListNodeController.self,
              context: .init(
                title: mode.title,
                titleIconName: mode.iconName
              )
            )

        case .foldersExplorer:
          return
            try features
            .instance(
              of: ResourceFolderContentNodeController.self,
              context: .init(
                folderDetails: .none
              )
            )
        }
      }
      catch {
        error
          .asTheError()
          .asFatalError(message: "Failed to update home screen.")
      }
    }

    return .init(
      viewState: viewState,
      activate: activate
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltHomeNavigationNodeController() {
    self.use(
      .disposable(
        HomeNavigationNodeController.self,
        load: HomeNavigationNodeController.load(features:context:)
      )
    )
  }
}
