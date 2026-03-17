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

internal final class HomeViewController: @MainActor ViewController {

  internal let viewState: ViewStateSource<ViewState>
  internal let setActiveNavigationState: @MainActor (NavigationState) -> Void

  private let homePresentation: HomePresentation
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
    let navigationStateRegistry: NavigationStateRegistry = try features.instance()
    self.setActiveNavigationState = navigationStateRegistry.setActive
    let resetNavigation: NavigationToRoot = try features.instance()
    self.homePresentation = try features.instance()
    var lastMode: HomePresentationMode? = .none
    self.viewState = .init(
      initial: .init(
        contentController: Self.contentRoot(
          for: .plainResourcesList,
          using: features
        )
      ),
      updateFrom: self.homePresentation.currentPresentationModeUpdatable(),
      update: { [features] (updateState, homePresentation) in
        guard lastMode != (try homePresentation.value)
        else {
          lastMode = try homePresentation.value
          return
        }

        await resetNavigation.performCatching()
        let contentController = Self.contentRoot(
          for: try homePresentation.value,
          using: features
        )
        updateState { (state: inout ViewState) in
          state.contentController = contentController
        }
      }
    )
  }
}

extension HomeViewController {

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

extension HomeViewController {

  @MainActor private static func contentRoot(
    for mode: HomePresentationMode,
    using features: Features
  ) -> any ViewController {
    do {

      switch mode {
      case .plainResourcesList, .modifiedResourcesList, .favoriteResourcesList,
        .sharedResourcesList, .ownedResourcesList, .expiredResourcesList:
        return
          try features
          .instance(
            of: ResourcesListViewController.self,
            context: .init(
              title: mode.title,
              titleIconName: mode.iconName,
              baseFilter: mode.baseFilter,
              appModeContext: .createExtensionContext(using: features, allowBack: false)
            )
          )

      case .tagsExplorer:
        return
          try features
          .instance(
            of: ResourceTagsListViewController.self,
            context: .init(
              title: mode.title,
              titleIconName: mode.iconName
            )
          )

      case .resourceUserGroupsExplorer:
        return
          try features
          .instance(
            of: ResourceUserGroupsListViewController.self,
            context: .init(
              title: mode.title,
              titleIconName: mode.iconName
            )
          )

      case .foldersExplorer:
        return
          try features
          .instance(
            of: ResourceFolderContentViewController.self,
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

  internal func closeExtension() {
    let autofillExtensionContext: AutofillExtensionContext = features.instance()
    autofillExtensionContext.cancelAndCloseExtension()
  }
}
