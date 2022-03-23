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
import Environment

import struct Foundation.Date
import struct Foundation.UUID

public typealias ResourcesRequest = NetworkRequest<
  AuthorizedNetworkSessionVariable, ResourcesRequestVariable, ResourcesRequestResponse
>

extension ResourcesRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariable: @AccountSessionActor @escaping () async throws -> AuthorizedNetworkSessionVariable
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain.rawValue),
          .pathSuffix("/resources.json"),
          .queryItem("contain[permission]", value: "1"),
          .queryItem("contain[favorite]", value: "1"),
          .header("Authorization", value: "Bearer \(sessionVariable.accessToken)"),
          .whenSome(
            sessionVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          ),
          .method(.get)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariable
    )
  }
}

public typealias ResourcesRequestVariable = Void

public typealias ResourcesRequestResponse = CommonResponse<ResourcesRequestResponseBody>

public typealias ResourcesRequestResponseBody = Array<ResourcesRequestResponseBodyItem>

public struct ResourcesRequestResponseBodyItem: Decodable {

  public var id: String
  public var resourceTypeID: String
  public var permission: Permission
  public var parentFolderID: String?
  public var name: String
  public var url: String?
  public var username: String?
  public var description: String?
  public var favorite: Bool
  public var modified: Date

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.url = try container.decodeIfPresent(String.self, forKey: .url)
    self.username = try container.decodeIfPresent(String.self, forKey: .username)
    self.description = try container.decodeIfPresent(String.self, forKey: .description)
    self.resourceTypeID = try container.decode(String.self, forKey: .resourceTypeID)
    self.parentFolderID = try container.decodeIfPresent(String.self, forKey: .parentFolderID)

    let permissionContainer = try container.nestedContainer(keyedBy: PermissionCodingKeys.self, forKey: .permission)
    self.permission = try permissionContainer.decode(Permission.self, forKey: .type)
    do {
      // favorite is an object but we don't care about its content
      // if it is present (not null) resource is favorite and not favorite otherwise
      let _ = try container.nestedContainer(
        keyedBy: FavoriteCodingKeys.self,
        forKey: .favorite
      )
      self.favorite = true
    }
    catch {
      self.favorite = false
    }
    self.modified = try container.decode(Date.self, forKey: .modified)
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case name = "name"
    case url = "uri"
    case username = "username"
    case description = "description"
    case resourceTypeID = "resource_type_id"
    case parentFolderID = "folder_parent_id"
    case permission = "permission"
    case favorite = "favorite"
    case modified = "modified"
  }

  private enum PermissionCodingKeys: String, CodingKey {

    case type = "type"
  }

  private enum FavoriteCodingKeys: CodingKey {}
}

extension ResourcesRequestResponseBodyItem {

  public enum Permission: Int, Decodable {

    case read = 1
    case write = 7
    case owner = 15
  }
}
