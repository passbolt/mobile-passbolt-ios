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

import class UIKit.UIColor
import enum UIKit.UIUserInterfaceStyle

public struct DynamicColor {

  private var color: (UIUserInterfaceStyle) -> UIColor

  public init(
    _ color: @escaping (UIUserInterfaceStyle) -> UIColor
  ) {
    self.color = color
  }

  public func withAlpha(_ value: CGFloat) -> Self {
    Self { userInterfaceStyle in
      self.color(userInterfaceStyle).withAlphaComponent(value)
    }
  }

  public func callAsFunction(
    in interfaceStyle: UIUserInterfaceStyle
  ) -> UIColor {
    color(interfaceStyle)
  }

  public static func always(_ colorRGB: Int32) -> Self {
    always(UIColor(colorRGB))
  }

  public static func always(_ color: UIColor?) -> Self {
    Self { _ in color ?? .clear }
  }

  public static func either(
    light lightColorRGB: Int32,
    orDark darkColorRGB: Int32
  ) -> Self {
    either(
      light: UIColor(lightColorRGB),
      orDark: UIColor(darkColorRGB)
    )
  }

  public static func either(
    light lightColor: UIColor?,
    orDark darkColor: UIColor?
  ) -> Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return darkColor ?? .clear

      case .light, _:
        return lightColor ?? .clear
      }
    }
  }

  /// Default/Light: #2A9CEB Dark: #2A9CEB
  public static var primaryBlue: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x2A9CEB)

      case .light, _:
        return UIColor(0x2A9CEB)
      }
    }
  }

  /// Default/Light: #2894DF Dark: #2894DF
  public static var primaryBluePressed: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x2894DF)

      case .light, _:
        return UIColor(0x2894DF)
      }
    }
  }

  /// Default/Light: #76BFF1 Dark: #76BFF1
  public static var primaryBlueDisabled: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x76BFF1)

      case .light, _:
        return UIColor(0x76BFF1)
      }
    }
  }

  /// Default/Light: #009900 Dark: #009900
  public static var secondaryGreen: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x009900)

      case .light, _:
        return UIColor(0x009900)
      }
    }
  }

  /// Default/Light: #FFBD2E Dark: #FFBD2E
  public static var secondaryOrange: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xFFBD2E)

      case .light, _:
        return UIColor(0xFFBD2E)
      }
    }
  }

  /// Default/Light: #D40101 Dark: #D40101
  public static var secondaryRed: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xD40101)

      case .light, _:
        return UIColor(0xD40101)
      }
    }
  }

  /// Default/Light: #FAC600 Dark: #FAC600
  public static var secondaryGray: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xF3F3F3)

      case .light, _:
        return UIColor(0xF3F3F3)
      }
    }
  }

  /// Default/Light: #E7F3E7 Dark: #E7F3E7
  public static var tintGreen: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xE7F3E7)

      case .light, _:
        return UIColor(0xE7F3E7)
      }
    }
  }

  /// Default/Light: #EAF3FA Dark: #EAF3FA
  public static var tintBlue: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xEAF3FA)

      case .light, _:
        return UIColor(0xEAF3FA)
      }
    }
  }

  /// Default/Light: #F8E7E7 Dark: #F8E7E7
  public static var tintRed: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xF8E7E7)

      case .light, _:
        return UIColor(0xF8E7E7)
      }
    }
  }

  /// Default/Light: #FFFAEB Dark: #FFFAEB
  public static var tintYellow: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xFFFAEB)

      case .light, _:
        return UIColor(0xFFFAEB)
      }
    }
  }

  /// Default/Light: #333333 Dark: #DDDDDD
  public static var primaryText: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xDDDDDD)

      case .light, _:
        return UIColor(0x333333)
      }
    }
  }

  /// Default/Light: #FFFFFF Dark: #000000
  public static var primaryTextAlternative: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x000000)

      case .light, _:
        return UIColor(0xFFFFFF)
      }
    }
  }

  /// Default/Light: #FFFFFF Dark: #000000
  public static var primaryButtonText: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xFFFFFF)

      case .light, _:
        return UIColor(0xFFFFFF)
      }
    }
  }

  /// Default/Light: #FFFFFF Dark: #000000
  public static var primaryButtonTint: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xFFFFFF)

      case .light, _:
        return UIColor(0x000000)
      }
    }
  }

  /// Default/Light: #666666 Dark: #B5B5B5
  public static var secondaryText: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0xB5B5B5)

      case .light, _:
        return UIColor(0x666666)
      }
    }
  }

  /// Default/Light: #888888 Dark: #888888
  public static var tertiaryText: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x888888)

      case .light, _:
        return UIColor(0x888888)
      }
    }
  }

  /// Default/Light: #FFFFFF Dark: #000000
  public static var background: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x000000)

      case .light, _:
        return UIColor(0xFFFFFF)
      }
    }
  }

  /// Default/Light: #FFFFFF Dark: #0F0F0F
  public static var backgroundAlternative: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x0F0F0F)

      case .light, _:
        return UIColor(0xFFFFFF)
      }
    }
  }

  /// Default/Light: #000000, alpha 0.4 Dark: #888888, alpha 0.4
  public static var overlayBackground: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x484848).withAlphaComponent(0.2)

      case .light, _:
        return UIColor(0x000000).withAlphaComponent(0.4)
      }
    }
  }

  /// Default/Light: #DDDDDD Dark: #0F0F0F
  public static var divider: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x0F0F0F)

      case .light, _:
        return UIColor(0xDDDDDD)
      }
    }
  }

  /// Default/Light: #888888 Dark: #888888
  public static var icon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x888888)

      case .light, _:
        return UIColor(0x888888)
      }
    }
  }

  /// Default/Light: #333333 Dark: #777777
  public static var iconAlternative: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIColor(0x777777)

      case .light, _:
        return UIColor(0x333333)
      }
    }
  }
}

extension UIColor {

  public convenience init(
    _ rgb: Int32
  ) {
    let red: Int32 = (rgb >> 16) & 0xFF
    let green: Int32 = (rgb >> 8) & 0xFF
    let blue: Int32 = rgb & 0xFF
    self.init(
      red: CGFloat(red) / 255.0,
      green: CGFloat(green) / 255.0,
      blue: CGFloat(blue) / 255.0,
      alpha: 1
    )
  }
}
