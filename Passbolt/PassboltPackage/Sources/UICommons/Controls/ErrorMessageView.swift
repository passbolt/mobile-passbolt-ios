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

internal class ErrorMessageView: View {

  private let label: Label = .init()

  internal required init() {
    super.init()
    setup()
  }

  internal func setText(_ text: String) {
    label.text = text
  }

  override internal func setup() {
    Mutation<Label>
      .combined(
        .font(.inter(ofSize: 12)),
        .textColor(dynamic: .secondaryRed),
        .numberOfLines(0),
        .subview(of: self),
        .edges(
          equalTo: self,
          insets: .init(
            top: -8,
            left: -8,
            bottom: -8,
            right: -8
          )
        )
      )
      .apply(on: label)

    Mutation<View>
      .combined(
        .accessibilityIdentifier("errorMessage"),
        .backgroundColor(dynamic: .background)
      )
      .apply(on: self)
  }
}

extension Mutation where Subject: ErrorMessageView {

  internal static func text(
    _ text: String
  ) -> Self {
    .custom { (subject: Subject) in
      subject.setText(text)
    }
  }

  internal static func text(
    displayable: DisplayableString,
    with arguments: Array<CVarArg> = .init()
  ) -> Self {
    .custom { (subject: Subject) in
      subject.setText(displayable.string(with: arguments))
    }
  }
}
