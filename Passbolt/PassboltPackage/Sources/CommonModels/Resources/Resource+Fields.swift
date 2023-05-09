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

// MARK: - General

extension Resource {

  public static func keyPath(
    for field: ResourceField
  ) -> WritableKeyPath<Resource, ResourceFieldValue> {
    \Resource[dynamicMember:field.valuePath]
  }

  public func value(
    for field: ResourceField
  ) -> ResourceFieldValue {
    value(for: field.valuePath)
  }

  public func value(
    forField name: StaticString
  ) -> ResourceFieldValue {
    value(for: ResourceField.valuePath(forName: name))
  }

  private func value(
    for path: ResourceField.ValuePath
  ) -> ResourceFieldValue {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else { return .unknown(.null) }
    return self.fieldValues[field.valuePath]
      ?? (field.encrypted ? .encrypted : .unknown(.null))
  }

  @discardableResult
  public mutating func set(
    _ value: ResourceFieldValue,
    for field: ResourceField
  ) throws -> Validated<ResourceFieldValue> {
    try self.set(
      value,
      for: field.valuePath
    )
  }

  @discardableResult
  public mutating func set(
    _ value: ResourceFieldValue,
    forField name: StaticString
  ) throws -> Validated<ResourceFieldValue> {
    try self.set(
      value,
      for: ResourceField.valuePath(forName: name)
    )
  }

  @discardableResult
  public mutating func set(
    _ value: ResourceFieldValue,
    for path: ResourceField.ValuePath
  ) throws -> Validated<ResourceFieldValue> {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set non existing field value!"
        )
    }
    guard field.accepts(value)
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set wrong field value!"
        )
    }

    self.fieldValues[field.valuePath] = value

    return field
      .validator
      .validate(self.value(for: field))
  }
}

// MARK: - TOTP

extension Resource {

  public func value<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    in field: ResourceField
  ) throws -> Value {
    try self.value(
      forTOTP: keyPath,
      at: field.valuePath
    )
  }

  public func value<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    inField name: StaticString
  ) throws -> Value {
    try self.value(
      forTOTP: keyPath,
      at: ResourceField.valuePath(forName: name)
    )
  }

  public func value<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    at path: ResourceField.ValuePath
  ) throws -> Value {
    guard
      let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path }),
      case .totp(let totp) = self.fieldValues[field.valuePath]
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to get non existing / invalid field value!"
        )
    }

    return totp[keyPath: keyPath]
  }

  @discardableResult
  public mutating func set<Value>(
    _ value: Value,
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    in field: ResourceField
  ) throws -> Validated<Value> {
    try self.set(
      value,
      forTOTP: keyPath,
      at: field.valuePath
    )
  }

  @discardableResult
  public mutating func set<Value>(
    _ value: Value,
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    inField name: StaticString
  ) throws -> Validated<Value> {
    try self.set(
      value,
      forTOTP: keyPath,
      at: ResourceField.valuePath(forName: name)
    )
  }

  @discardableResult
  public mutating func set<Value>(
    _ value: Value,
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    at path: ResourceField.ValuePath
  ) throws -> Validated<Value> {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set non existing field value!"
        )
    }

    guard case .totp(var totp) = self.fieldValues[field.valuePath]
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to set wrong field value!"
        )
    }

    totp[keyPath: keyPath] = value

    self.fieldValues[field.valuePath] = .totp(totp)

    if let validationError: TheError = ResourceField.totpValidators[keyPath]?(totp) {
      return .invalid(
        value,
        error: validationError
      )
    }
    else {
      return .valid(value)
    }
  }
}
