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

internal final class HomeViewController: ViewController {

  internal struct ViewState: Equatable, Sendable {

    internal var currentPresentation: HomePresentationMode = .plainResourcesList
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal let setActiveNavigationState: @MainActor (NavigationState) -> Void

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
    let homePresentation: HomePresentation = try features.instance()
    var lastMode: HomePresentationMode? = .none
    self.viewState = .init(
      initial: .init(),
      updateFrom: homePresentation.currentPresentationModeUpdatable(),
      update: { update, presentation in
        guard lastMode != (try presentation.value)
        else {
          lastMode = try presentation.value
          return
        }
        let newPresentation: HomePresentationMode = try presentation.value
        await resetNavigation.performCatching()
        update { (state: inout ViewState) in
          state.currentPresentation = newPresentation
        }
      }
    )
  }
}

extension HomeViewController {

  internal typealias Context = SessionScope.Context
}

extension HomeViewController {

  internal func prepareResourcesList(
    for mode: HomePresentationMode
  ) -> ResourcesListViewController {
    do {
      return try features.instance(
        context: .init(
          title: mode.title,
          titleIconName: mode.iconName,
          baseFilter: mode.baseFilter,
          appModeContext: .createExtensionContext(using: features, allowBack: false)
        )
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Failed to create ResourcesListViewController.")
    }
  }

  internal func prepareController<Controller>(
    _ type: Controller.Type = Controller.self,
    context: Controller.Context
  ) -> Controller where Controller: ViewController {
    do {
      return try features.instance(context: context)
    }
    catch {
      error
        .asTheError()
        .recording(String(describing: type), for: "Controller")
        .asFatalError(message: "Failed to create home controller.")
    }
  }

  internal func closeExtension() {
    let autofillExtensionContext: AutofillExtensionContext = features.instance()
    autofillExtensionContext.cancelAndCloseExtension()
  }
}
