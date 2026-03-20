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
import Session

internal final class StartupErrorViewController: @MainActor ViewController {

  internal typealias Context = () async throws -> Void

  internal struct ViewState: Equatable {

    internal var alert: AlertViewModel?
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let session: Session
  private let navigationToSelf: NavigationToStartupError

  internal init(context: @escaping Context, features: Features) throws {
    self.context = context
    self.viewState = .init(initial: .init())
    self.session = try features.instance()
    self.navigationToSelf = try features.instance()
  }

  internal func refresh() async {
    await consumingErrors {
      try await self.context()
    }
  }

  internal func signOut() async {
    self.viewState.update(
      \.alert,
      to: .init(
        title: "account.settings.alert.title",
        message: "account.settings.signout.alert.message",
        actions: [
          .cancel(id: .init(), title: .localized(key: .cancel)),
          .destructive(
            id: .init(),
            title: .localized(key: .signOut),
            perform: { [weak self] in await self?.exit() }
          ),
        ]
      )
    )
  }

  private func exit() async {
    await self.navigationToSelf.revertCatching()
    await self.session.close(.none)
  }
}
