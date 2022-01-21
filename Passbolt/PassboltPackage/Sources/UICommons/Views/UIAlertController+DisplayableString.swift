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

import AegithalosCocoa
import Commons

extension Mutation where Subject: UIAlertController {

  @inlinable public static func title(
    _ displayableString: DisplayableString,
    with arguments: Array<CVarArg> = .init()
  ) -> Self {
    Self { (subject: Subject) in
      subject.title = displayableString.string(with: arguments)
    }
  }

  @inlinable public static func message(
    _ displayableString: DisplayableString,
    with arguments: Array<CVarArg> = .init()
  ) -> Self {
    Self { (subject: Subject) in
      subject.message = displayableString.string(with: arguments)
    }
  }

  @inlinable public static func action(
    _ displayableString: DisplayableString,
    with arguments: Array<CVarArg> = .init(),
    style: UIAlertAction.Style = .default,
    accessibilityIdentifier: String? = nil,
    handler: @escaping () -> Void
  ) -> Self {
    Self { (subject: Subject) in
      let action = UIAlertAction(
        title: displayableString.string(with: arguments),
        style: style,
        handler: { _ in handler() }
      )
      action.accessibilityIdentifier = accessibilityIdentifier
      subject.addAction(action)
    }
  }
}
