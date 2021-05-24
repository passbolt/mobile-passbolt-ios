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

// "One Error to rule them all, One Error to handle them, One Error to bring them all, and on the screen bind them"
public struct TheError: Error {
  
  public typealias ID = Tagged<String, TheError>
  public typealias Extension = Tagged<String, ID>
  
  public let identifier: ID
  public let underlyingError: Error?
  public var extensions: Dictionary<Extension, Any>
  
  public init(
    identifier: ID,
    underlyingError: Error?,
    extensions: Dictionary<Extension, Any>
  ) {
    self.identifier = identifier
    self.underlyingError = underlyingError
    self.extensions = extensions
  }
}

extension TheError {
  
  public mutating func extend(
    with extension: Extension,
    value: Any
  ) {
    extensions[`extension`] = value
  }
  
  public func extended(
    with extension: Extension,
    value: Any
  ) -> Self {
    var mutable: Self = self
    mutable.extend(with: `extension`, value: value)
    return mutable
  }
  
  public var logMessage: String? { extensions[.logMessage] as? String }
  
  public mutating func append(
    logMessage: String
  ) {
    extensions[.logMessage] = extensions[.logMessage]
      .map { "\($0)\n\(logMessage)" } ?? logMessage
  }
  
  public func appending(
    logMessage: String
  ) -> Self {
    var mutable: Self = self
    mutable.append(logMessage: logMessage)
    return mutable
  }
  
  public var context: String? { extensions[.context] as? String }
  
  public mutating func append(
    context: String
  ) {
    extensions[.context] = extensions[.context]
      .map { "\($0)-\(context)" } ?? context
  }
  
  public func appending(
    context: String
  ) -> Self {
    var mutable: Self = self
    mutable.append(context: context)
    return mutable
  }
  
  public var localizationKey: String? { extensions[.localizationKey] as? String }
}

extension TheError: CustomDebugStringConvertible {
  
  public var debugDescription: String {
    """
    ---
    Error: \(identifier)
    UnderlyingError: \(underlyingError.map { "\($0)" } ?? "N/A")
    Extensions:
    \(extensions.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
    ---
    """
  }
}

extension TheError {
  
  public static func ~= (
    _ lhs: TheError.ID,
    _ rhs: TheError
  ) -> Bool {
    lhs == rhs.identifier
  }
}

extension TheError.ID {
  
  public static let canceled: Self = "canceled"
}

extension TheError.Extension {
  
  public static let logMessage: Self = "logMessage"
  public static let context: Self = "context"
}

extension TheError {
  
  public static let canceled: Self = .init(
    identifier: .canceled,
    underlyingError: nil,
    extensions: [.context: "canceled"]
  )
}

extension TheError.Extension {
  
  public static var localizationKey: Self { "localizationKey" }
}
