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

public typealias FoldersRequest = NetworkRequest<
  AuthorizedNetworkSessionVariable, FoldersRequestVariable, FoldersRequestResponse
>

extension FoldersRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<AuthorizedNetworkSessionVariable, Error>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain.rawValue),
          .pathSuffix("/folders.json"),
          .queryItem("contain[permission]", value: "1"),
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
      with: sessionVariablePublisher
    )
  }
}

public typealias FoldersRequestVariable = Void

public typealias FoldersRequestResponse = CommonResponse<FoldersRequestResponseBody>

public typealias FoldersRequestResponseBody = Array<FoldersRequestResponseBodyItem>

public struct FoldersRequestResponseBodyItem: Decodable {

  public var id: String
  public var name: String
  public var permission: Permission
  public var parentFolderID: String?

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.parentFolderID = try container.decodeIfPresent(String.self, forKey: .parentFolderID)

    let permissionContainer = try container.nestedContainer(keyedBy: PermissionCodingKeys.self, forKey: .permission)
    self.permission = try permissionContainer.decode(Permission.self, forKey: .type)
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case name = "name"
    case parentFolderID = "folder_parent_id"
    case permission = "permission"
  }

  private enum PermissionCodingKeys: String, CodingKey {

    case type = "type"
  }

  private enum FavoriteCodingKeys: CodingKey {}
}

extension FoldersRequestResponseBodyItem {

  public enum Permission: Int, Decodable {

    case read = 1
    case write = 7
    case owner = 15
  }
}
