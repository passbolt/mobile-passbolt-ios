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

import struct Foundation.URL

public typealias ConfigRequest =
  NetworkRequest<AuthorizedNetworkSessionVariable, ConfigRequestVariable, ConfigResponse>

extension ConfigRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariable: @AccountSessionActor @escaping () async throws -> AuthorizedNetworkSessionVariable
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain.rawValue),
          .pathSuffix("/settings.json"),
          .method(.get),
          .queryItem("api-version", value: "v2"),
          .header("Authorization", value: "Bearer \(sessionVariable.accessToken)"),
          .whenSome(
            sessionVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          )
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariable
    )
  }
}

public typealias ConfigRequestVariable = Void
public typealias ConfigResponse = CommonResponse<ConfigResponseBody>

public struct Config: Decodable {

  public var legal: Legal?
  public var plugins: Array<Plugin>

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let plugins = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: CodingKeys.plugins)

    self.plugins = []
    self.legal = try container.decode(Legal?.self, forKey: CodingKeys.legal)

    if let folders: Folders = try plugins.decodeIfPresent(
      Folders.self,
      forKey: "folders"
    ) {
      self.plugins.append(folders)
    }
    else {
      /* NOP */
    }

    if let previewPassword: PreviewPassword = try plugins.decodeIfPresent(
      PreviewPassword.self,
      forKey: "previewPassword"
    ) {
      self.plugins.append(previewPassword)
    }
    else {
      /* NOP */
    }

    if let tags: Tags = try plugins.decodeIfPresent(
      Tags.self,
      forKey: "tags"
    ) {
      self.plugins.append(tags)
    }
    else {
      /* NOP */
    }
  }

  internal init(
    legal: Legal?,
    plugins: Array<Plugin>
  ) {
    self.legal = legal
    self.plugins = plugins
  }

  private enum CodingKeys: String, CodingKey {

    case legal = "legal"
    case plugins = "plugins"
  }
}

extension Config {

  public struct Legal: Decodable, Equatable {

    public struct Item: Decodable, Equatable {

      public var url: String
    }

    public var privacyPolicy: Item
    public var terms: Item

    private enum CodingKeys: String, CodingKey {

      case privacyPolicy = "privacy_policy"
      case terms = "terms"
    }
  }
}

public protocol Plugin {}

extension Config {

  public struct PreviewPassword: Decodable, Equatable, Plugin {

    public var enabled: Bool
  }

  public struct Folders: Decodable, Equatable, Plugin {

    public var enabled: Bool
    public var version: String
  }

  public struct Tags: Decodable, Equatable, Plugin {

    public var enabled: Bool
    public var version: String
  }
}

public struct ConfigResponseBody: Decodable {

  public var config: Config

  private enum CodingKeys: String, CodingKey {

    case config = "passbolt"
  }
}
