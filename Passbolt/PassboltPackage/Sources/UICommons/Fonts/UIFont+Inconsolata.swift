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

import CommonModels
import UIKit

extension UIFont {

  private static let register: Void = {
    func registerFont(fileName: String) {
      guard
        let pathForResourceString = Bundle.module.path(forResource: fileName, ofType: "ttf"),
        let fontData = NSData(contentsOfFile: pathForResourceString),
        let dataProvider = CGDataProvider(data: fontData),
        let fontRef = CGFont(dataProvider)
      else { return }

      CTFontManagerRegisterGraphicsFont(fontRef, nil)
    }
    registerFont(fileName: "Inconsolata Bold")
    registerFont(fileName: "Inconsolata SemiBold")
  }()

  public static func inconsolata(
    ofSize fontSize: CGFloat,
    weight: UIFont.Weight = .regular
  ) -> UIFont {
    _ = register
    let font: UIFont?
    switch weight {
    case .bold:
      font = UIFont(
        name: "Inconsolata Bold",
        size: fontSize
      )
    case .semibold:
      font = UIFont(
        name: "Inconsolata SemiBold",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }

    return font
      ?? .monospacedSystemFont(
        ofSize: fontSize,
        weight: weight
      )
  }
}
