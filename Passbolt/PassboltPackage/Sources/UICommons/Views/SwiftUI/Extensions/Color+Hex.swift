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

extension Color {
  public typealias Hex = Tagged<String, Self>
  /// Creates a Color from a hex string.
  public init?(hex: Hex) {
    if let rgba: RGBA = .init(hex: hex) {
      self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
    else {
      return nil
    }
  }

  /// Calculates the luminance of a color based on its hex string and returns either black or white.
  public static func luminance(for hex: Hex) -> Color? {
    if Self.isFullyTransparent(hex: hex) {
      return Color.passboltIconAlternative
    }
    guard let color: RGBA = .init(hex: hex) else {
      return nil
    }

    let r255 = color.red * 255
    let g255 = color.green * 255
    let b255 = color.blue * 255
    let luminance = (r255 * 299 + g255 * 587 + b255 * 114) / 1000
    return luminance > 125 ? .black : .white
  }

  public static func isFullyTransparent(hex: Hex) -> Bool {
    guard let rgba: RGBA = .init(hex: hex) else {
      return false
    }
    return rgba.alpha == 0.0
  }

  private struct RGBA {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
      self.red = red
      self.green = green
      self.blue = blue
      self.alpha = alpha
    }

    init?(hex: Hex) {
      let hex = hex.rawValue.replacingOccurrences(of: "#", with: "")

      // Support both RRGGBB and RRGGBBAA formats
      guard hex.count == 6 || hex.count == 8 else { return nil }

      let scanner = Scanner(string: hex)
      var rgbaValue: UInt64 = 0

      guard scanner.scanHexInt64(&rgbaValue) else { return nil }

      // For 8 character hex (RRGGBBAA)
      if hex.count == 8 {
        let red = Double((rgbaValue & 0xFF00_0000) >> 24) / 255.0
        let green = Double((rgbaValue & 0x00FF_0000) >> 16) / 255.0
        let blue = Double((rgbaValue & 0x0000_FF00) >> 8) / 255.0
        let alpha = Double(rgbaValue & 0x0000_00FF) / 255.0

        self = .init(red: red, green: green, blue: blue, alpha: alpha)
      }
      // For 6 character hex (RRGGBB)
      else {
        let red = Double((rgbaValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbaValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbaValue & 0x0000FF) / 255.0
        self = .init(red: red, green: green, blue: blue, alpha: 1.0)
      }
    }
  }
}
