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

import SwiftUI

extension Font {

  public static func inter(
    ofSize fontSize: CGFloat,
    weight: Font.Weight = .regular
  ) -> Self {
    UIFont.registerFontsIfNeeded()
    let font: Font?
    switch weight {
    case .black:
      font = .custom(
        "Inter Black",
        size: fontSize
      )

    case .bold:
      font = .custom(
        "Inter Bold",
        size: fontSize
      )

    case .semibold:
      font = .custom(
        "Inter Semi Bold",
        size: fontSize
      )

    case .light:
      font = .custom(
        "Inter Light",
        size: fontSize
      )

    case .ultraLight:
      font = .custom(
        "Inter Extra Light",
        size: fontSize
      )

    case .medium:
      font = .custom(
        "Inter Medium",
        size: fontSize
      )

    case .regular:
      font = .custom(
        "Inter Regular",
        size: fontSize
      )

    case .thin:
      font = .custom(
        "Inter Thin",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }

    return font
      ?? .system(
        size: fontSize,
        weight: weight,
        design: .default
      )
  }

  public static func interItalic(
    ofSize fontSize: CGFloat,
    weight: Font.Weight = .regular
  ) -> Self {
    UIFont.registerFontsIfNeeded()
    let font: Font?
    switch weight {
    case .light:
      font = .custom(
        "Inter LightItalic",
        size: fontSize
      )

    case .regular:
      font = .custom(
        "Inter Italic",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }

    return font
      ?? .system(
        size: fontSize,
        weight: weight,
        design: .default
      )
      .italic()
  }
}
