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

import Accounts
import Display
import FeatureScopes
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceSearchDisplayController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>
  internal nonisolated let searchText: any ViewStateSource<String>

  private let currentAccount: Account
  private let diagnostics: OSDiagnostics
  private let navigationTree: NavigationTree
  private let asyncExecutor: AsyncExecutor
  private let session: Session
  private let accountDetails: AccountDetails

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.currentAccount = try features.sessionAccount()

    self.diagnostics = features.instance()
    self.navigationTree = features.instance()
    self.asyncExecutor = try features.instance()
    self.session = try features.instance()
    self.accountDetails = try features.instance(context: currentAccount)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        searchPrompt: context.searchPrompt,
        accountAvatar: .none,
        searchText: ""
      )
    )

    self.viewState = viewState
    self.searchText = ComputedViewState(from: viewState, at: \.searchText)
  }
}

extension ResourceSearchDisplayController {

  internal struct Context {

    internal var searchPrompt: DisplayableString
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var searchPrompt: DisplayableString
    internal var accountAvatar: Data?
    internal var searchText: String
  }
}

extension ResourceSearchDisplayController {

  internal final func activate() async {
    do {
      let avatar: Data? = try await self.accountDetails.avatarImage()
      await self.viewState.update { state in
        state.accountAvatar = avatar
      }
    }
    catch {
      self.diagnostics.log(
        error: error,
        info: .message(
          "Failed to load account avatar image, using placeholder."
        )
      )
    }
  }

  internal final func showPresentationMenu() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failAction: { [context] (error: Error) in
        await context.showMessage(.error(error))
      },
      behavior: .reuse
    ) { [features, navigationTree] in
      try await navigationTree.present(
        .sheet,
        HomePresentationMenuNodeView.self,
        controller: features.instance()
      )
    }
  }

  internal final func signOut() {
    self.asyncExecutor.schedule(.reuse) { [unowned self] in
      await self.session.close(.none)
    }
  }
}
