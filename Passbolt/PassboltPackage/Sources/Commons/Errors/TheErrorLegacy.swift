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

import Localization

import class Foundation.Bundle
import struct Foundation.OSStatus

// Legacy error definition, please switch to `TheError`.
// `TheErrorLegacy` will be removed after migrating all errors to new system.
@available(*, deprecated, message: "Please switch to `TheError`")
public struct TheErrorLegacy: Error {

  public typealias ID = Tagged<StaticString, TheErrorLegacy>
  public typealias Extension = Tagged<StaticString, ID>

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

  public var asLegacy: TheErrorLegacy { .from(theError: self) }
}

extension Error {

  public var asLegacy: TheErrorLegacy {
    if let theError: TheError = self as? TheError {
      return .from(theError: theError)
    }
    else if self is CancellationError {
      return .from(
        theError:
          Cancelled
          .error()
          .recording(self, for: "underlyingError")
      )
    }
    else {
      return .from(theError: self.asUnidentified())
    }
  }

  public func pushing(
    _ info: DiagnosticsInfo,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Error {
    ((self as? TheError)
      ?? (self as? CancellationError)
      .map { _ in
        Cancelled
          .error()
          .recording(self, for: "underlyingError")
      }
      ?? self.asUnidentified(file: file, line: line))
      .pushing(info)
  }
}

extension TheErrorLegacy {

  public static func from(
    theError: TheError
  ) -> Self {
    Self(
      identifier: theError is Cancelled ? .canceled : .legacyBridge,
      underlyingError: theError,
      extensions: [
        .legacyBridge: theError,
        .displayableString: theError.displayableMessage,
        .logMessage: theError.diagnosticMessages.first as Any,
      ]
    )
  }

  public var legacyBridge: TheError? { extensions[.legacyBridge] as? TheError }
  public func isLegacyBridge<Err: TheError>(
    for errorType: Err.Type,
    // additional, optional validation for specific fields check
    verification: (Err) -> Bool = { _ in true }
  ) -> Bool {
    (self.extensions[.legacyBridge] as? Err).map(verification) ?? false
  }
}

extension TheErrorLegacy.ID {

  public static var legacyBridge: Self { "legacyBridge" }
}

extension TheErrorLegacy.Extension {

  public static var legacyBridge: Self { "legacyBridge" }
}

extension TheErrorLegacy {

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

  public var logMessage: String? {
    (extensions[.logMessage] as? Array<StaticString>)?
      .map(\.description)
      .joined(separator: "\n")
  }

  public mutating func append(
    logMessage: StaticString
  ) {
    var messages: Array<StaticString> =
      extensions[.logMessage]
      as? Array<StaticString>
      ?? .init()
    messages.append(logMessage)
    extensions[.logMessage] = messages
  }

  public func appending(
    logMessage: StaticString
  ) -> Self {
    var mutable: Self = self
    mutable.append(logMessage: logMessage)
    return mutable
  }

  #if DEBUG
  public var debugLogMessage: String? { extensions[.debugLogMessage] as? String }
  #endif

  public mutating func append(
    debugLogMessage: String
  ) {
    #if DEBUG
    extensions[.debugLogMessage] =
      extensions[.debugLogMessage]
      .map { "\($0)\n\(debugLogMessage)" } ?? debugLogMessage
    #endif
  }

  public func appending(
    debugLogMessage: String
  ) -> Self {
    #if DEBUG
    var mutable: Self = self
    mutable.append(debugLogMessage: debugLogMessage)
    return mutable
    #else
    return self
    #endif
  }

  public var context: String? { extensions[.context] as? String }

  public mutating func append(
    context: String
  ) {
    extensions[.context] =
      extensions[.context]
      .map { "\($0)-\(context)" } ?? context
  }

  public func appending(
    context: String
  ) -> Self {
    var mutable: Self = self
    mutable.append(context: context)
    return mutable
  }

  public var displayableString: DisplayableString? { extensions[.displayableString] as? DisplayableString }
  public var displayableStringArguments: Array<CVarArg>? { extensions[.displayableStringArguments] as? Array<CVarArg> }
}

extension TheErrorLegacy: CustomStringConvertible {

  public var description: String {
    #if DEBUG
    debugDescription
    #else
    "TheError: \(identifier)\(context.map { ", \($0)" } ?? "")"
    #endif
  }
}

#if DEBUG
extension TheErrorLegacy: CustomDebugStringConvertible {

  public var debugDescription: String {
    """
    -TheError-
    \(identifier)\(debugLogMessage.map { "\nDebug log:\($0)" } ?? "")\(logMessage.map { "\nLog:\($0)" } ?? "")
    UnderlyingError: \(underlyingError.map { "\($0)" } ?? "N/A")
    Extensions:
    \(extensions.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
    ---
    """
  }
}
#endif

extension TheErrorLegacy {

  public static func ~= (
    _ lhs: TheErrorLegacy.ID,
    _ rhs: TheErrorLegacy
  ) -> Bool {
    lhs == rhs.identifier
  }
}

extension TheErrorLegacy.ID {

  public static let canceled: Self = "canceled"
  public static let featureUnavailable: Self = "featureUnavailable"
  public static let internalInconsistency: Self = "internalInconsistency"
}

extension TheErrorLegacy.Extension {

  public static let logMessage: Self = "logMessage"
  #if DEBUG
  public static let debugLogMessage: Self = "debugLogMessage"
  #endif
  public static let context: Self = "context"
}

extension TheErrorLegacy {

  public static let canceled: Self = .init(
    identifier: .canceled,
    underlyingError: nil,
    extensions: [.context: "canceled"]
  )

  public static func featureUnavailable(
    featureName: StaticString,
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .featureUnavailable,
      underlyingError: underlyingError,
      extensions: [.context: "\(featureName)"]
    )
  }

  public static func internalInconsistency(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .internalInconsistency,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }
}

extension TheErrorLegacy.Extension {

  public static var displayableString: Self { "displayableString" }
  public static var displayableStringArguments: Self { "displayableStringArguments" }
}

extension TheErrorLegacy.Extension {

  public static var osStatus: Self { "osStatus" }
}

extension TheErrorLegacy {

  public var osStatus: OSStatus? { extensions[.osStatus] as? OSStatus }
}
