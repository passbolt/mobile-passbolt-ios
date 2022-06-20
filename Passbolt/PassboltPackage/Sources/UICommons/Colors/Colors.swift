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

// swift-format-ignore: NeverForceUnwrap
extension UIColor {

  public static var passboltPrimaryBlue: Self {
    .init(named: "primaryBlue", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSecondaryGreen: Self {
    .init(named: "secondaryGreen", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSecondaryOrange: Self {
    .init(named: "secondaryOrange", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSecondaryRed: Self {
    .init(named: "secondaryRed", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSecondaryGray: Self {
    .init(named: "secondaryGray", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltTintGreen: Self {
    .init(named: "tintGreen", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltTintBlue: Self {
    .init(named: "tintBlue", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltTintRed: Self {
    .init(named: "tintRed", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltTintYellow: Self {
    .init(named: "tintYellow", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltPrimaryButtonTint: Self {
    .init(named: "primaryButtonTint", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltPrimaryText: Self {
    .init(named: "primaryText", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltPrimaryTextInverted: Self {
    .init(named: "primaryTextInverted", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltPrimaryAlertText: Self {
    .init(named: "primaryAlertText", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSecondaryText: Self {
    .init(named: "secondaryText", in: .uiCommons, compatibleWith: .current)!
  }
  public static var passboltTertiaryText: Self {
    .init(named: "tertiaryText", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltPrimaryButtonText: Self {
    .init(named: "primaryButtonText", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltBackground: Self {
    .init(named: "background", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltSheetBackground: Self {
    .init(named: "sheetBackground", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltDivider: Self {
    .init(named: "divider", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltIcon: Self {
    .init(named: "icon", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltIconAlternative: Self {
    .init(named: "iconAlternative", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltBackgroundAlternative: Self {
    .init(named: "backgroundAlternative", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltBackgroundAlert: Self {
    .init(named: "backgroundAlert", in: .uiCommons, compatibleWith: .current)!
  }

  public static var passboltBackgroundLoader: Self {
    .init(named: "backgroundLoader", in: .uiCommons, compatibleWith: .current)!
  }
}

extension Color {

  public static var passboltPrimaryBlue: Self {
    .init(UIColor.passboltPrimaryBlue)
  }

  public static var passboltSecondaryGreen: Self {
    .init(UIColor.passboltSecondaryGreen)
  }

  public static var passboltSecondaryOrange: Self {
    .init(UIColor.passboltSecondaryOrange)
  }

  public static var passboltSecondaryRed: Self {
    .init(UIColor.passboltSecondaryRed)
  }

  public static var passboltSecondaryGray: Self {
    .init(UIColor.passboltSecondaryGray)
  }

  public static var passboltTintGreen: Self {
    .init(UIColor.passboltTintGreen)
  }

  public static var passboltTintBlue: Self {
    .init(UIColor.passboltTintBlue)
  }

  public static var passboltTintRed: Self {
    .init(UIColor.passboltTintRed)
  }

  public static var passboltTintYellow: Self {
    .init(UIColor.passboltTintYellow)
  }

  public static var passboltPrimaryButtonTint: Self {
    .init(UIColor.passboltPrimaryButtonTint)
  }

  public static var passboltPrimaryText: Self {
    .init(UIColor.passboltPrimaryText)
  }

  public static var passboltPrimaryTextInverted: Self {
    .init(UIColor.passboltPrimaryTextInverted)
  }

  public static var passboltPrimaryAlertText: Self {
    .init(UIColor.passboltPrimaryAlertText)
  }

  public static var passboltSecondaryText: Self {
    .init(UIColor.passboltSecondaryText)
  }

  public static var passboltTertiaryText: Self {
    .init(UIColor.passboltTertiaryText)
  }
  public static var passboltPrimaryButtonText: Self {
    .init(UIColor.passboltPrimaryButtonText)
  }

  public static var passboltBackground: Self {
    .init(UIColor.passboltBackground)
  }

  public static var passboltSheetBackground: Self {
    .init(UIColor.passboltSheetBackground)
  }

  public static var passboltDivider: Self {
    .init(UIColor.passboltDivider)
  }

  public static var passboltIcon: Self {
    .init(UIColor.passboltIcon)
  }

  public static var passboltIconAlternative: Self {
    .init(UIColor.passboltIconAlternative)
  }

  public static var passboltBackgroundAlternative: Self {
    .init(UIColor.passboltBackgroundAlternative)
  }

  public static var passboltBackgroundAlert: Self {
    .init(UIColor.passboltBackgroundAlert)
  }

  public static var passboltBackgroundLoader: Self {
    .init(UIColor.passboltBackgroundLoader)
  }
}
