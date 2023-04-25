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

// MARK: - Validation

extension Resource {

  public func validateField(
    _ field: ResourceField
  ) throws {
    try self.validateField(
      field.valuePath
    )
  }

  public func validateField(
    _ name: StaticString
  ) throws {
    try self.validateField(
      ResourceField.valuePath(forName: name)
    )
  }

  public func validateField(
    _ path: ResourceField.ValuePath
  ) throws {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else {
      throw
        InvalidResourceData
        .error(
          message: "Trying to valide non existing field value!"
        )
    }

    let error: Error? = field
      .validator
      .validate(self.value(for: field))
      .error

    if let error {
      throw error
    } // else NOP
  }

  public func validate() throws {
    for field in self.fields {
      let error: TheError? = field
        .validator
        .validate(self.value(for: field))
        .error

      if let error {
        throw error
      }
      else {
        continue
      }
    }
  }

  public func validatedValue(
    for field: ResourceField
  ) -> Validated<ResourceFieldValue> {
    validatedValue(for: field.valuePath)
  }

  public func validatedValue(
    forField name: StaticString
  ) -> Validated<ResourceFieldValue> {
    validatedValue(for: ResourceField.valuePath(forName: name))
  }

  public func validatedValue(
    for path: ResourceField.ValuePath
  ) -> Validated<ResourceFieldValue> {
    guard let field: ResourceField = self.type.fields.first(where: { $0.valuePath == path })
    else {
      return .invalid(
        .unknown(.null),
        error: InvalidValue.alwaysInvalid(
          value: ResourceFieldValue.unknown(.null),
          displayable: "error.generic"
        )
      )
    }

    return field
      .validator
      .validate(self.value(for: field))
  }
}

// MARK: - TOTP

extension Resource {

  public func validatedValue<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    in field: ResourceField
  ) throws -> Validated<Value> {
    try self.validatedValue(
      forTOTP: keyPath,
      at: field.valuePath
    )
  }

  public func validatedValue<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    inField name: StaticString
  ) throws -> Validated<Value> {
    try self.validatedValue(
      forTOTP: keyPath,
      at: ResourceField.valuePath(forName: name)
    )
  }

  public func validatedValue<Value>(
    forTOTP keyPath: WritableKeyPath<TOTPSecret, Value>,
    at path: ResourceField.ValuePath
  ) throws -> Validated<Value> {
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

    let value: Value = totp[keyPath: keyPath]

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
