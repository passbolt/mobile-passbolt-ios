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

/// Keepass icon set mapping for custom resource icons
public enum KeepassIcons: IconProvider {
  private static let namespace: String = "KeepassIconSet"
  private static let passwordIconName: String = "key"
  private static let totpIconName: String = "totp"
  private static let passwordAndTotpIconName: String = "password_with_totp"
  private static let customFieldsIconName: String = "custom_fields"

  /// Get all available keepass icon identifiers
  public static var availableIdentifiers: [String] {
    (0 ... 68).map { String($0) }
  }

  public static func icon(for value: ResourceIcon.IconIdentifier) -> Image? {
    let paddedValue = String(format: "%02d", Int(value.rawValue) ?? 0)
    return Image(Self.namespace + "/" + paddedValue, bundle: .module)
  }

  public static func icon(for slug: ResourceSpecification.Slug) -> Image? {
    let iconName: String
    switch slug {
    case .passwordWithTOTP, .v5DefaultWithTOTP:
      iconName = Self.passwordAndTotpIconName
    case .totp, .v5StandaloneTOTP:
      iconName = Self.totpIconName
    case .v5CustomFields:
      iconName = Self.customFieldsIconName
    default:
      iconName = Self.passwordIconName
    }

    return Image(Self.namespace + "/" + iconName, bundle: .module)
  }
}
