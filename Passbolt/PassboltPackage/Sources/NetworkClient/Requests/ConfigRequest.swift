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

public typealias ConfigRequest =
  NetworkRequest<DomainSessionVariable, ConfigRequestVariable, ConfigResponse>

extension ConfigRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<DomainSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain),
          .path("/settings.json"),
          .method(.get),
          .queryItem("api-version", value: "v2")
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public typealias ConfigRequestVariable = Void
public typealias ConfigResponse = CommonResponse<ConfigResponseBody>

public struct Config: Decodable {

  public struct Legal: Decodable {

    public struct Item: Decodable {

      public var url: String
    }

    public var privacyPolicy: Item
    public var terms: Item

    private enum CodingKeys: String, CodingKey {

      case privacyPolicy = "privacy_policy"
      case terms = "terms"
    }
  }

  public var legal: Legal?
}

public struct ConfigResponseBody: Decodable {

  public var config: Config

  private enum CodingKeys: String, CodingKey {

    case config = "passbolt"
  }
}
