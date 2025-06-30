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

public struct ResourceIcon: Codable, Equatable, Sendable, Hashable {
  public typealias IconIdentifier = Tagged<String, Self>
  public static let none = ResourceIcon(type: nil, value: nil, backgroundColor: nil)

  public let type: IconType
  public let value: IconIdentifier?
  public let backgroundColor: String?

  public var json: JSON {
    var json: JSON = .object(.init())
    json[keyPath: \.type] = .string(type.rawValue)
    json[keyPath: \.value] = value.flatMap { .string($0.rawValue) } ?? .null
    json[keyPath: \.background_color] = backgroundColor.flatMap { .string($0) } ?? .null
    return json
  }

  public init(type: IconType?, value: IconIdentifier?, backgroundColor: String?) {
    self.type = type ?? .keepassIconSet
    self.value = value
    self.backgroundColor = backgroundColor
  }

  public init(json: JSON) {
    self.type = json[keyPath: \.type].stringValue.flatMap(IconType.init(rawValue:)) ?? .keepassIconSet
    self.value = json[keyPath: \.value].stringValue.flatMap { .init(rawValue: $0) }
    self.backgroundColor = json[keyPath: \.background_color].stringValue
  }

  public enum IconType: String, CaseIterable, Codable, Sendable, Hashable {
    case keepassIconSet = "keepass-icon-set"

    public var availableIdentifiers: [IconIdentifier] {
      switch self {
      case .keepassIconSet:
        return (0 ... 68)  // based on assets
          .map { String(format: "%02d", $0) }
          .map { IconIdentifier(rawValue: String($0)) }
      }
    }
  }
}
