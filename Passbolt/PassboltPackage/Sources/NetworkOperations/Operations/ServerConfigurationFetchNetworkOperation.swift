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

public typealias ServerConfigurationFetchNetworkOperation =
  NetworkOperation<ServerConfigurationFetchNetworkOperationDescription>

public enum ServerConfigurationFetchNetworkOperationDescription: NetworkOperationDescription {

  public typealias Output = ServerConfiguration
}

public struct ServerConfiguration: Decodable {

  public var legal: Legal
  public var plugins: Plugins

  public init(
    legal: Legal,
    plugins: Plugins
  ) {
    self.legal = legal
    self.plugins = plugins
  }

  public init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let nestedContainer = try container.nestedContainer(
      keyedBy: NestedCodingKeys.self,
      forKey: .configuration
    )
    self.legal = try nestedContainer.decode(
      Legal.self,
      forKey: .legal
    )
    self.plugins = try nestedContainer.decode(
      Plugins.self,
      forKey: .plugins
    )
  }

  private enum CodingKeys: String, CodingKey {

    case configuration = "passbolt"
  }

  private enum NestedCodingKeys: String, CodingKey {

    case legal = "legal"
    case plugins = "plugins"
  }
}

extension ServerConfiguration {

  public struct Legal: Decodable, Equatable {

    public var privacyPolicy: URLString?
    public var terms: URLString?

    public init(
      privacyPolicy: URLString?,
      terms: URLString?
    ) {
      self.privacyPolicy = privacyPolicy
      self.terms = terms
    }

    public init(
      from decoder: Decoder
    ) throws {
      let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
      self.privacyPolicy =
        try container.nestedContainer(
          keyedBy: ItemCodingKeys.self,
          forKey: .privacyPolicy
        )
        .decodeIfPresent(
          URLString.self,
          forKey: .url
        )
      self.terms =
        try container.nestedContainer(
          keyedBy: ItemCodingKeys.self,
          forKey: .terms
        )
        .decodeIfPresent(
          URLString.self,
          forKey: .url
        )
    }

    private enum CodingKeys: String, CodingKey {

      case privacyPolicy = "privacy_policy"
      case terms = "terms"
    }

    private enum ItemCodingKeys: String, CodingKey {

      case url = "url"
    }
  }
}

extension ServerConfiguration {

  public struct Plugins: Decodable {

    public var passwordPreview: PasswordPreview?
    public var folders: Folders?
    public var tags: Tags?
    public var totpResources: TOTPResources?
    public var rbacs: RBAC?

    public init(
      passwordPreview: PasswordPreview?,
      folders: Folders?,
      tags: Tags?,
      totpResources: TOTPResources?,
      rbacs: RBAC?
    ) {
      self.passwordPreview = passwordPreview
      self.folders = folders
      self.tags = tags
      self.totpResources = totpResources
      self.rbacs = rbacs
    }

    private enum CodingKeys: String, CodingKey {

      case passwordPreview = "previewPassword"
      case folders = "folders"
      case tags = "tags"
      case totpResources = "totpResourceTypes"
      case rbacs = "rbacs"
    }
  }
}

extension ServerConfiguration.Plugins {

  public struct PasswordPreview: Decodable {

    public var enabled: Bool

    public init(
      enabled: Bool
    ) {
      self.enabled = enabled
    }
  }

  public struct Folders: Decodable {

    public var enabled: Bool

    public init(
      enabled: Bool
    ) {
      self.enabled = enabled
    }
  }

  public struct Tags: Decodable {

    public var enabled: Bool

    public init(
      enabled: Bool
    ) {
      self.enabled = enabled
    }
  }

  public struct TOTPResources: Decodable {

    public var enabled: Bool

    public init(
      enabled: Bool
    ) {
      self.enabled = enabled
    }
  }

  public struct RBAC: Decodable {

    public var enabled: Bool

    public init(
      enabled: Bool
    ) {
      self.enabled = enabled
    }
  }
}
