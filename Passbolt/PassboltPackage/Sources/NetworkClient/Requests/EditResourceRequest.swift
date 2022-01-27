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

import struct Foundation.Data

public typealias UpdateResourceRequest = NetworkRequest<
  AuthorizedNetworkSessionVariable, UpdateResourceRequestVariable, UpdateResourceRequestResponse
>

extension UpdateResourceRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<AuthorizedNetworkSessionVariable, Error>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain.rawValue),
          .pathSuffix("/resources/\(requestVariable.resourceID).json"),
          .header("Authorization", value: "Bearer \(sessionVariable.accessToken)"),
          .whenSome(
            sessionVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          ),
          .jsonBody(from: requestVariable),
          .method(.put)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct UpdateResourceRequestVariable: Encodable {

  public var resourceID: String
  public var resourceTypeID: String
  public var name: String
  public var username: String?
  public var url: String?
  public var description: String?
  public var secrets: Array<Secret>

  public struct Secret: Encodable {

    public var userID: String
    public var data: String

    public enum CodingKeys: String, CodingKey {

      case userID = "user_id"
      case data = "data"
    }
  }

  public init(
    resourceID: String,
    resourceTypeID: String,
    name: String,
    username: String?,
    url: String?,
    description: String?,
    secrets: Array<(userID: String, data: String)>
  ) {
    self.resourceID = resourceID
    self.resourceTypeID = resourceTypeID
    self.name = name
    self.username = username
    self.url = url
    self.description = description
    self.secrets = secrets.map { Secret(userID: $0.userID, data: $0.data) }
  }

  public enum CodingKeys: String, CodingKey {

    case name = "name"
    case description = "description"
    case username = "username"
    case url = "uri"
    case resourceTypeID = "resource_type_id"
    case secrets = "secrets"
  }
}

public typealias UpdateResourceRequestResponse = CommonResponse<UpdateResourceRequestResponseBody>

public struct UpdateResourceRequestResponseBody: Decodable {

  public var resourceID: String

  public init(
    resourceID: String
  ) {
    self.resourceID = resourceID
  }

  public enum CodingKeys: String, CodingKey {

    case resourceID = "id"
  }
}
