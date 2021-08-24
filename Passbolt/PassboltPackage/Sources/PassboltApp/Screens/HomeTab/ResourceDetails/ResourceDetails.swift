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

import Accounts
import Commons

extension ResourceDetailsController {

  internal typealias FieldName = Tagged<String, ResourceDetailsController>
}

extension ResourceDetailsController {

  internal struct ResourceDetails: Equatable {

    internal enum Permission: String {

      case read = "read"
      case write = "write"
      case owner = "owner"

      fileprivate static func from(resourcePermission: ResourcePermission) -> Permission {
        guard let permission: Permission = .init(rawValue: resourcePermission.rawValue)
        else {
          assertionFailure("Invalid rawValue")
          return .read
        }

        return permission
      }
    }

    internal enum Field: Comparable, Hashable {

      case username(required: Bool, encrypted: Bool, maxLength: Int?)
      case password(required: Bool, encrypted: Bool, maxLength: Int?)
      case uri(required: Bool, encrypted: Bool, maxLength: Int?)
      case description(required: Bool, encrypted: Bool, maxLength: Int?)

      fileprivate static func from(resourceField: ResourceField) -> Field? {
        switch resourceField {
        case let .string("username", required, encrypted, maxLength):
          return .username(required: required, encrypted: encrypted, maxLength: maxLength)
        case let .string("password", required, encrypted, maxLength),
             let .string("secret", required, encrypted, maxLength):
          return .password(required: required, encrypted: encrypted, maxLength: maxLength)
        case let .string("uri", required, encrypted, maxLength):
          return .uri(required: required, encrypted: encrypted, maxLength: maxLength)
        case let .string("description", required, encrypted, maxLength):
          return .description(required: required, encrypted: encrypted, maxLength: maxLength)
        case _:
          return nil
        }
      }

      internal func name() -> FieldName {
        switch self {
        case .username:
          return "username"
        case .password:
          return "password"
        case .uri:
          return "uri"
        case .description:
          return "description"
        }
      }

      static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.username, _):
          return true
        case (.password, .username), (.password, .password):
          return false
        case (.password, .uri), (.password, .description):
          return true
        case (.uri, .username), (.uri, .password), (.uri, .uri):
          return false
        case (.uri, .description):
          return true
        case (.description, _):
          return false
        }
      }
    }

    internal typealias ID = Tagged<String, ResourceDetails>

    internal let id: ID
    internal var permission: Permission
    internal var name: String
    internal var url: String?
    internal var username: String?
    internal var description: String?
    internal var fields: Array<Field>

    internal static func from(detailsViewResource: DetailsViewResource) -> ResourceDetails {

      let fields: Array<ResourceDetails.Field> = detailsViewResource.fields
        .compactMap(ResourceDetails.Field.from(resourceField:))
        .sorted()

      return .init(
        id: .init(rawValue: detailsViewResource.id.rawValue),
        permission: .from(resourcePermission: detailsViewResource.permission),
        name: detailsViewResource.name,
        url: detailsViewResource.url,
        username: detailsViewResource.username,
        description: detailsViewResource.description,
        fields: fields
      )
    }
  }
}
