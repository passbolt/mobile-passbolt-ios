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
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal struct HomeNavigationNodeController {

  @IID internal var id
  @NavigationNodeID public var nodeID
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension HomeNavigationNodeController: ViewNodeController {

  internal struct ViewState: Hashable {

    internal var contentController: AnyDisplayController
  }

  internal struct ViewActions: ViewControllerActions {

    internal var activate: @Sendable () async -> Void

    #if DEBUG
    internal static var placeholder: Self {
      .init(
        activate: { unimplemented() }
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

extension HomeNavigationNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let nodeID: NavigationNodeID = .init()
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let navigationTree: NavigationTree = features.instance()
    let homePresentation: HomePresentation = try await features.instance()

    let state: StateBinding<ViewState> = await .variable(
      initial: .init(
        contentController: contentRoot(
          for: homePresentation.currentMode.get()
        )
      )
    )

    let viewState: ViewStateBinding<ViewState> = .init(stateSource: state)

    @Sendable nonisolated func activate() async {
      asyncExecutor.schedule(.reuse) {
        do {
          try await homePresentation
            .currentMode
            .asAnyAsyncSequence()
            .forLatest { (mode: HomePresentationMode) in
              await state.set(
                \.contentController,
                to: contentRoot(for: mode)
              )
              navigationTree.dismiss(upTo: nodeID)
            }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message("Home navigation mode updates broken.")
          )
        }
      }
    }

    @Sendable nonisolated func contentRoot(
      for mode: HomePresentationMode
    ) async -> AnyDisplayController {
      do {
        switch mode {
        case .plainResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
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
          )

        case .modifiedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
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
          )

        case .favoriteResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
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
          )

        case .sharedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
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
          )

        case .ownedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
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
          )

        case .tagsExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceTagsListNodeController.self,
                context: .init(
                  title: mode.title,
                  titleIconName: mode.iconName
                )
              )
          )

        case .resourceUserGroupsExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceUserGroupsListNodeController.self,
                context: .init(
                  title: mode.title,
                  titleIconName: mode.iconName
                )
              )
          )

        case .foldersExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceFolderContentNodeController.self,
                context: .init(
                  folderDetails: .none
                )
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
      nodeID: nodeID,
      viewState: viewState,
      viewActions: .init(
        activate: activate
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltHomeNavigationNodeController() {
    self.use(
      .disposable(
        HomeNavigationNodeController.self,
        load: HomeNavigationNodeController.load(features:)
      )
    )
  }
}
