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

public enum ResourceFieldNameTag {}
public typealias ResourceFieldName = Tagged<String, ResourceFieldNameTag>

extension ResourceFieldName {

  public var displayable: DisplayableString {
    switch self {
    case .name:
      return "resource.edit.field.name.label"
    case .uri:
      return "resource.edit.field.uri.label"
    case .username:
      return "resource.edit.field.username.label"
    case .password, .secret:
      return "resource.edit.field.password.label"
    case .description:
      return "resource.edit.field.description.label"
    case .totp:
      return "resource.edit.field.totp.label"
    case .secretKey:
      return "otp.edit.form.field.secret.title"
    default:
      return .raw(self.rawValue)
    }
  }

  public var displayableViewingPlaceholder: DisplayableString {
    switch self {
    case .uri:
      return "resource.show.field.uri.placeholder"

    case .username:
      return "resource.show.field.username.placeholder"

    case .password, .secret:
      return "resource.show.field.password.placeholder"

    case .description:
      return "resource.show.field.description.placeholder"

    case _:
      return .raw("")
    }
  }

  public var displayableEditingPlaceholder: DisplayableString {
    switch self.rawValue {
    case "name":
      return "resource.edit.field.name.placeholder"

    case "uri":
      return "resource.edit.field.uri.placeholder"

    case "username":
      return "resource.edit.field.username.placeholder"

    case "password", "secret":
      return "resource.edit.field.password.placeholder"

    case "description":
      return "resource.edit.field.description.placeholder"

    case "secret_key":
      return "otp.edit.form.field.secret.prompt"

    case _:
      return .raw("")
    }
  }

  public static let name: ResourceFieldName = "name"
  public static let uri: ResourceFieldName = "uri"
  public static let username: ResourceFieldName = "username"
  public static let password: ResourceFieldName = "password"
  public static let description: ResourceFieldName = "description"
  public static let note: ResourceFieldName = "note"
  public static let totp: ResourceFieldName = "totp"
  public static let secretKey: ResourceFieldName = "secret_key"
  public static let secret: ResourceFieldName = "secret"

}
