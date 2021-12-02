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

public typealias AccountTransferUpdateRequest = NetworkRequest<
  EmptyNetworkSessionVariable, AccountTransferUpdateRequestVariable, AccountTransferUpdateResponse
>

extension AccountTransferUpdateRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { _, requestVariable in
        .combined(
          .url(string: requestVariable.domain.rawValue),
          .path("/mobile/transfers/\(requestVariable.transferID)/\(requestVariable.authenticationToken).json"),
          .method(.put),
          .when(
            requestVariable.requestUserProfile,
            then: .queryItem("contain[user.profile]", value: "1")
          ),
          .jsonBody(
            from: AccountTransferUpdateRequestVariable.Body(
              currentPage: requestVariable.currentPage,
              status: requestVariable.status
            )
          )
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct AccountTransferUpdateRequestVariable {

  public var domain: URLString
  public var authenticationToken: String
  public var transferID: String
  public var currentPage: Int
  public var status: Status
  public var requestUserProfile: Bool

  public init(
    domain: URLString,
    authenticationToken: String,
    transferID: String,
    currentPage: Int,
    status: Status,
    requestUserProfile: Bool
  ) {
    self.domain = domain
    self.authenticationToken = authenticationToken
    self.transferID = transferID
    self.currentPage = currentPage
    self.status = status
    self.requestUserProfile = requestUserProfile
  }
}

extension AccountTransferUpdateRequestVariable {

  public enum Status: String, Encodable {

    case inProgress = "in progress"
    case complete = "complete"
    case error = "error"
    case cancel = "cancel"
  }

  public struct Body: Encodable {

    public var currentPage: Int
    public var status: Status

    internal enum CodingKeys: String, CodingKey {

      case currentPage = "current_page"
      case status = "status"
    }
  }
}

public typealias AccountTransferUpdateResponse = CommonResponse<AccountTransferUpdateResponseBody>

public struct AccountTransferUpdateResponseBody: Decodable {

  public var user: User?
}

extension AccountTransferUpdateResponseBody {

  public struct User: Decodable {

    public var username: String
    public var profile: Profile
  }
}

extension AccountTransferUpdateResponseBody.User {

  public struct Profile: Decodable {

    public var firstName: String
    public var lastName: String
    public var avatar: Avatar

    public enum CodingKeys: String, CodingKey {

      case firstName = "first_name"
      case lastName = "last_name"
      case avatar = "avatar"
    }
  }
}

extension AccountTransferUpdateResponseBody.User.Profile {

  public struct Avatar: Decodable {

    public var url: Image
  }
}

extension AccountTransferUpdateResponseBody.User.Profile.Avatar {

  public struct Image: Decodable {

    public var medium: String
  }
}
