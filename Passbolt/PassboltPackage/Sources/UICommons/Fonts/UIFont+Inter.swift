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

import Commons
import UIKit

extension UIFont {

  public static func inter(
    ofSize fontSize: CGFloat,
    weight: UIFont.Weight = .regular
  ) -> UIFont {
    let font: UIFont?
    switch weight {
    case .black:
      font = UIFont(
        name: "Inter-Black",
        size: fontSize
      )

    case .bold:
      font = UIFont(
        name: "Inter Bold",
        size: fontSize
      )

    case .semibold:
      font = UIFont(
        name: "Inter SemiBold",
        size: fontSize
      )

    case .light:
      font = UIFont(
        name: "Inter Light",
        size: fontSize
      )

    case .ultraLight:
      font = UIFont(
        name: "Inter ExtraLight",
        size: fontSize
      )

    case .medium:
      font = UIFont(
        name: "Inter Medium",
        size: fontSize
      )

    case .regular:
      font = UIFont(
        name: "Inter Regular",
        size: fontSize
      )

    case .thin:
      font = UIFont(
        name: "Inter Thin",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }
    return font
      ?? .systemFont(
        ofSize: fontSize,
        weight: weight
      )
  }
}
