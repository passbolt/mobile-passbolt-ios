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
import CommonModels

extension Mutation where Subject: PlainView {

  public static func snackBarErrorMessage(
    _ displayable: DisplayableString = .localized(key: .genericError),
    with arguments: Array<CVarArg> = .init()
  ) -> Self {
    snackBarMessage(
      displayable,
      with: arguments,
      backgroundColor: .secondaryRed,
      textColor: .primaryButtonText
    )
  }

  public static func snackBarMessage(
    _ displayable: DisplayableString,
    with arguments: Array<CVarArg> = .init(),
    backgroundColor: DynamicColor,
    textColor: DynamicColor
  ) -> Self {
    .combined(
      .backgroundColor(dynamic: backgroundColor),
      .cornerRadius(4, masksToBounds: true),
      .custom { (subject: Subject) in
        Mutation<Label>
          .combined(
            .accessibilityIdentifier("snackbar.message"),
            .numberOfLines(0),
            .lineBreakMode(.byWordWrapping),
            .font(.inter(ofSize: 14, weight: .regular)),
            .textColor(dynamic: textColor),
            .textAlignment(.left),
            .subview(of: subject),
            .edges(
              equalTo: subject,
              insets: .init(
                top: -16,
                left: -16,
                bottom: -16,
                right: -16
              ),
              usingSafeArea: false
            ),
            .text(displayable: displayable, with: arguments)
          )
          .instantiate()
      }
    )
  }
}
