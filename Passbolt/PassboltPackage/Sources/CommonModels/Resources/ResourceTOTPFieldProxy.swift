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

@dynamicMemberLookup
public final class ResourceTOTPFieldProxy {

  private let fieldPath: ResourceField.ValuePath
  // `access` function is used to both read and write values,
  // it is made in such a way to ensure exclusive access to the Resource
  // which is required due to its async nature.
  // It is required to make sure that value won't be modified after reading
  // while before writing again (which could cause data loss)
  private let access: ((inout Resource) throws -> Void) async throws -> Resource

  public init(
    fieldPath: ResourceField.ValuePath,
    access: @escaping ((inout Resource) throws -> Void) async throws -> Resource
  ) {
    self.fieldPath = fieldPath
    self.access = access
  }

  public var rawValue: TOTPSecret {
    get async throws {
      try await self.read()
        .value(
          forTOTP: \.self,
          at: self.fieldPath
        )
    }
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<TOTPSecret, Value>
  ) -> Value {
    get async throws {
      try await self.read()
        .value(
          forTOTP: keyPath,
          at: self.fieldPath
        )
    }
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<TOTPSecret, Value>
  ) -> Validated<Value> {
    get async throws {
      try await self.read()
        .validatedValue(
          forTOTP: keyPath,
          at: self.fieldPath
        )
    }
  }

  private func read() async throws -> Resource {
    try await access { _ throws in }
  }
}

extension ResourceTOTPFieldProxy {

  @discardableResult
  public func value<Value>(
    for keyPath: WritableKeyPath<TOTPSecret, Value>
  ) async throws -> Value {
    try await self.read()
      .value(
        forTOTP: keyPath,
        at: self.fieldPath
      )
  }

  @discardableResult
  public func validatedValue<Value>(
    for keyPath: WritableKeyPath<TOTPSecret, Value>
  ) async throws -> Validated<Value> {
    try await self.read()
      .validatedValue(
        forTOTP: keyPath,
        at: self.fieldPath
      )
  }

  @discardableResult
  public func update<Value>(
    _ keyPath: WritableKeyPath<TOTPSecret, Value>,
    to value: Value
  ) async throws -> Validated<Value> {
    try await self.access { (resource: inout Resource) throws in
      try resource
        .set(
          value,
          forTOTP: keyPath,
          at: self.fieldPath
        )
    }
    .validatedValue(
      forTOTP: keyPath,
      at: self.fieldPath
    )
  }
}
