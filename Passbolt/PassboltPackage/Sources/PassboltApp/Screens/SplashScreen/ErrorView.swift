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

import UICommons

internal final class ErrorView: View {

  internal var refreshTapPublisher: AnyPublisher<Void, Never> { refreshButton.tapPublisher }
  internal var signOutTapPublisher: AnyPublisher<Void, Never> { signOutButton.tapPublisher }

  private let refreshButton: TextButton = .init()
  private let signOutButton: TextButton = .init()

  internal required init() {
    super.init()

    let errorStateView: ErrorStateView = .init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    mut(errorStateView) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, topAnchor, constant: 90),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
    }

    mut(refreshButton) {
      .combined(
        .primaryStyle(),
        .text(
          localized: .refresh,
          inBundle: .commons
        ),
        .subview(of: self),
        .topAnchor(.equalTo, errorStateView.bottomAnchor, constant: 30),
        .leadingAnchor(.equalTo, errorStateView.leadingAnchor),
        .trailingAnchor(.equalTo, errorStateView.trailingAnchor)
      )
    }

    mut(signOutButton) {
      .combined(
        .primaryStyle(),
        .text(
          localized: .signOut,
          inBundle: .commons
        ),
        .subview(of: self),
        .topAnchor(.equalTo, refreshButton.bottomAnchor, constant: 15),
        .leadingAnchor(.equalTo, errorStateView.leadingAnchor),
        .trailingAnchor(.equalTo, errorStateView.trailingAnchor)
      )
    }
  }
}
