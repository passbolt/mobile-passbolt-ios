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
import Foundation

public struct ResourceMetadata: Sendable {
  public let resourceId: Resource.ID
  public private(set) var json: JSON = .null
  public var name: String {
    didSet {
      json[keyPath: \.name] = .string(name)
    }
  }

  public var username: String? {
    didSet {
      if let username {
        json[keyPath: \.username] = .string(username)
      }
      else {
        json[keyPath: \.username] = .null
      }
    }
  }

  public var description: String? {
    didSet {
      if let description {
        json[keyPath: \.description] = .string(description)
      }
      else {
        json[keyPath: \.description] = .null
      }
    }
  }

  public var icon: ResourceIcon? {
    didSet {
      if let icon {
        let iconData = try? JSONEncoder().encode(icon)
        if let iconData = iconData,
          let iconObject = try? JSONSerialization.jsonObject(with: iconData) as? [String: Any]
        {
          var iconJSON: [String: JSON] = [:]
          for (key, value) in iconObject {
            if let stringValue = value as? String {
              iconJSON[key] = .string(stringValue)
            }
            else if let intValue = value as? Int {
              iconJSON[key] = .integer(intValue)
            }
          }
          json[keyPath: \.icon] = .object(iconJSON)
        }
      }
      else {
        json[keyPath: \.icon] = .null
      }
    }
  }

  /// Initializes a new `ResourceMetadata` instance.
  /// - Parameters:
  ///  - resourceId: The resource ID.
  ///  - json: The JSON object.
  /// - Throws: `InternalInconsistency` if the JSON object is missing the name.
  public init(resourceId: Resource.ID, json: JSON) throws {
    guard let name = json[keyPath: \.name].stringValue
    else {
      throw InternalInconsistency.error("ResourceMetadata: missing name")
    }
    self.resourceId = resourceId
    self.name = name
    self.json = json
    self.username = json[keyPath: \.username].stringValue
    self.description = json[keyPath: \.description].stringValue

    if case .object(let iconObject) = json[keyPath: \.icon] {
      let iconData = try? JSONSerialization.data(withJSONObject: iconObject)
      self.icon = iconData.flatMap { try? JSONDecoder().decode(ResourceIcon.self, from: $0) }
    }
    else {
      self.icon = nil
    }
  }
}
