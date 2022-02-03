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

internal final class UnsupportedMFAView: PlainView {

  private let resultView: ResultView = .init()

  internal required init() {
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    mut(resultView) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .centerYAnchor(.equalTo, centerYAnchor, constant: -56),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }

    resultView
      .applyOn(
        image: .image(named: .failureMark, from: .uiCommons)
      )
    resultView
      .applyOn(
        title: .text(displayable: .localized(key: "mfa.unsupported.provider.title"))
      )

    resultView
      .applyOn(
        message: .text(displayable: .localized(key: "mfa.unsupported.provider.description"))
      )

    resultView
      .applyOn(
        button: .hidden(true)
      )
  }
}
