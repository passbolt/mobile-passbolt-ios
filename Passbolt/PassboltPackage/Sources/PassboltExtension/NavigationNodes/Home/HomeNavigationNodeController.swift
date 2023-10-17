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
import FeatureScopes
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class HomeNavigationNodeController: ViewController {

  internal let viewState: ViewStateSource<ViewState>

  private let navigationTree: NavigationTree
  private let homePresentation: HomePresentation
  @available(*, deprecated, message: "Do not use viewNodeID to identify views. Legacy use only!")
  public let viewNodeID: ViewNodeID

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    let features: Features =
      try features
			.branch(
				scope: AccountScope.self,
				context: context.account
			)
      .branch(
        scope: SessionScope.self,
        context: context
      )
    self.features = features
    self.viewNodeID = .init(rawValue: .init(Self.self))

    self.navigationTree = features.instance()
    self.homePresentation = try features.instance()

    self.viewState = .init(
      initial: .init(
        contentController: Self.contentRoot(
          for: homePresentation.currentMode.get(),
          using: features,
          nodeID: self.viewNodeID
        )
      ),
      updateFrom: self.homePresentation.currentMode.updates,
      update: { [homePresentation, navigationTree, viewNodeID, features] (updateState, _) in
        let contentController = await Self.contentRoot(
          for: homePresentation.currentMode.get(),
          using: features,
          nodeID: viewNodeID
        )
        await updateState { (state: inout ViewState) in
          state.contentController = contentController
        }
      }
    )
  }
}

extension HomeNavigationNodeController {

  internal typealias Context = SessionScope.Context

  internal struct ViewState: Equatable {

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
}

extension HomeNavigationNodeController {

  @MainActor private static func contentRoot(
    for mode: HomePresentationMode,
    using features: Features,
    nodeID: ViewNodeID
  ) -> any ViewController {
    do {
      switch mode {
      case .plainResourcesList:
        return
          try features
          .instance(
            of: ResourcesListNodeController.self,
            context: .init(
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
              nodeID: nodeID,
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
}
