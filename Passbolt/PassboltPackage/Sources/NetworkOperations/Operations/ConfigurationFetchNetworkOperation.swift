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

import Features

// MARK: - Interface

public typealias ConfigurationFetchNetworkOperation =
  NetworkOperation<ConfigurationFetchNetworkOperationDescription>

public enum ConfigurationFetchNetworkOperationDescription: NetworkOperationDescription {

  public typealias Output = ConfigurationFetchNetworkOperationResult
}

public struct ConfigurationFetchNetworkOperationResult: Decodable {

  public var config: Config

  public init(
    config: Config
  ) {
    self.config = config
  }

  private enum CodingKeys: String, CodingKey {

    case config = "passbolt"
  }
}

extension ConfigurationFetchNetworkOperationResult {

  public struct Config: Decodable {

    public var legal: Legal?
    public var plugins: Array<ConfigurationPlugin>

    public init(
      from decoder: Decoder
    ) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let plugins = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: CodingKeys.plugins)

      self.plugins = []
      self.legal = try container.decode(Legal?.self, forKey: CodingKeys.legal)

      if let folders: ConfigurationPlugins.Folders = try plugins.decodeIfPresent(
        ConfigurationPlugins.Folders.self,
        forKey: "folders"
      ) {
        self.plugins.append(folders)
      }
      else {
        /* NOP */
      }

      if let previewPassword: ConfigurationPlugins.PreviewPassword = try plugins.decodeIfPresent(
        ConfigurationPlugins.PreviewPassword.self,
        forKey: "previewPassword"
      ) {
        self.plugins.append(previewPassword)
      }
      else {
        /* NOP */
      }

      if let tags: ConfigurationPlugins.Tags = try plugins.decodeIfPresent(
        ConfigurationPlugins.Tags.self,
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
      plugins: Array<ConfigurationPlugin>
    ) {
      self.legal = legal
      self.plugins = plugins
    }

    private enum CodingKeys: String, CodingKey {

      case legal = "legal"
      case plugins = "plugins"
    }
  }

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

public protocol ConfigurationPlugin {}

public enum ConfigurationPlugins {

  public struct PreviewPassword: Decodable, Equatable, ConfigurationPlugin {

    public var enabled: Bool
  }

  public struct Folders: Decodable, Equatable, ConfigurationPlugin {

    public var enabled: Bool
    public var version: String
  }

  public struct Tags: Decodable, Equatable, ConfigurationPlugin {

    public var enabled: Bool
    public var version: String
  }
}
