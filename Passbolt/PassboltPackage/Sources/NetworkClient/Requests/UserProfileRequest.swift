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
import Environment

public typealias UserProfileRequest =
NetworkRequest<AuthorizedSessionVariable, UserProfileRequestVariable, UserProfileRequestResponse>

extension UserProfileRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<AuthorizedSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
          .combined(
            .url(string: sessionVariable.domain),
            .whenSome(
              requestVariable.userID,
              then: { userID in
                .path("/users/\(userID).json")
              },
              else: .path("/users/me.json")
            ),
            .header("Authorization", value: "Bearer \(sessionVariable.authorizationToken)"),
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

public struct UserProfileRequestVariable {

  public var userID: String?

  public init(
    userID: String? = nil
  ) {
    self.userID = userID
  }
}

public typealias UserProfileRequestResponse = CommonResponse<UserProfileRequestResponseBody>

public struct UserProfileRequestResponseBody: Decodable {

  public var profile: Profile

  public init(
    profile: Profile
  ) {
    self.profile = profile
  }
}

extension UserProfileRequestResponseBody {

  public struct Profile: Decodable {

    public var firstName: String
    public var lastName: String
    public var avatar: Avatar

    public init(
      firstName: String,
      lastName: String,
      avatar: Avatar
    ) {
      self.firstName = firstName
      self.lastName = lastName
      self.avatar = avatar
    }

    public enum CodingKeys: String, CodingKey {

      case firstName = "first_name"
      case lastName = "last_name"
      case avatar = "avatar"
    }
  }
}

extension UserProfileRequestResponseBody.Profile {

  public struct Avatar: Decodable {

    public var url: Image

    public init(
      url: Image
    ) {
      self.url = url
    }
  }
}

extension UserProfileRequestResponseBody.Profile.Avatar {

  public struct Image: Decodable {

    public var medium: String

    public init(
      medium: String
    ) {
      self.medium = medium
    }
  }
}
