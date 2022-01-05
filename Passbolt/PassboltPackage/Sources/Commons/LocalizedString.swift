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

import struct AegithalosCocoa.LocalizationKeyConstant
import class Foundation.Bundle
import func Foundation.NSLocalizedString

public struct LocalizedString {

  public typealias Key = LocalizationKeyConstant

  public static func localized(
    key: Key,
    tableName: String? = .none,
    bundle: Bundle = .main,
    arguments: Array<CVarArg> = .init()
  ) -> Self {
    Self(
      key: key,
      tableName: tableName,
      bundle: bundle,
      arguments: arguments
    )
  }

  public let key: Key
  public let tableName: String?
  public let bundle: Bundle
  public var arguments: Array<CVarArg>

  internal init(
    key: Key,
    tableName: String?,
    bundle: Bundle,
    arguments: Array<CVarArg>
  ) {
    self.key = key
    self.tableName = tableName
    self.bundle = bundle
    self.arguments = arguments
  }

  public func resolve(
    with arguments: Array<CVarArg> = .init(),
    localizaton: (_ key: Key, _ tableName: String?, _ bundle: Bundle) -> String = {
      (key: Key, tableName: String?, bundle: Bundle) -> String in
      NSLocalizedString(
        key.rawValue,
        tableName: tableName,
        bundle: bundle,
        comment: ""
      )
    }
  ) -> String {
    let string: String = localizaton(self.key, self.tableName, self.bundle)

    let joinedArguments: Array<CVarArg> = self.arguments + arguments

    if joinedArguments.isEmpty {
      return string
    }
    else {
      return String(
        format: string,
        arguments: joinedArguments
      )
    }
  }
}

extension LocalizedString: Hashable {

  public static func == (
    _ lhs: LocalizedString,
    _ rhs: LocalizedString
  ) -> Bool {
    lhs.key.rawValue == rhs.key.rawValue
      && lhs.bundle == rhs.bundle
      && lhs.tableName == rhs.tableName
    // can't really check arguments, skipping
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(key.rawValue)
    hasher.combine(bundle)
    hasher.combine(tableName)
    // can't really combine arguments, skipping
  }
}

extension LocalizedString: ExpressibleByStringLiteral {

  public init(
    stringLiteral: StaticString
  ) {
    self.init(
      key: .init(
        stringLiteral: stringLiteral
      ),
      tableName: .none,
      bundle: .main,
      arguments: .init()
    )
  }
}
