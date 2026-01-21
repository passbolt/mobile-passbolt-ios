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

internal final class AccountExportInfoViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var alert: AlertViewModel?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState> = .init(initial: .init())
  private let navigationToAccountExportAuthorization: NavigationToAccountExportAuthorization
  private let navigationToSelf: NavigationToAccountExportInfo

  internal init(context: Void, features: Features) throws {
    self.navigationToAccountExportAuthorization = try features.instance()
    self.navigationToSelf = try features.instance()
  }

  internal func back() async {
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }

  internal func start() async {
    await consumingErrors {
      try await self.navigationToAccountExportAuthorization.perform()
    }
  }
}
