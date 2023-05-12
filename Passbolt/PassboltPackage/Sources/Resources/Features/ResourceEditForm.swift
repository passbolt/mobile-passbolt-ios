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

import CommonModels
import Features

// MARK: - Interface

public struct ResourceEditForm {

  // Access current resource state and updates
  public var state: ViewableState<Resource>
  // Update resource
  public var update: @Sendable (@escaping (inout Resource) -> Void) async throws -> Resource
  // Send the form
  public var sendForm: @Sendable () async throws -> Resource.ID

  public init(
    state: ViewableState<Resource>,
    update: @escaping @Sendable (@escaping (inout Resource) -> Void) async throws -> Resource,
    sendForm: @escaping @Sendable () async throws -> Resource.ID
  ) {
    self.state = state
    self.update = update
    self.sendForm = sendForm
  }
}

extension ResourceEditForm: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Self {
    .init(
      state: .placeholder,
      update: { _ in unimplemented() },
      sendForm: unimplemented0()
    )
  }
  #endif
}

extension ResourceEditForm {

  @discardableResult
  @Sendable public func update(
    _ field: Resource.FieldPath,
    to value: JSON
  ) async throws -> Validated<JSON> {
    try await self.update { (resource: inout Resource) in
      resource[keyPath: field] = value
    }
    .validator(for: field).validate(value)
  }

  @discardableResult
  @Sendable public func update<Value>(
    _ field: Resource.FieldPath,
    to value: Value,
    valueToJSON: (Value) throws -> JSON,
    jsonToValue: (JSON) throws -> Value
  ) async throws -> Validated<Value> {
    let jsonValue: JSON
    do {
      jsonValue = try valueToJSON(value)
    }
    catch {
      // if conversion fails update to null (or should mabe skip the update?)
      _ = try await self.update { (resource: inout Resource) in
        resource[keyPath: field] = .null
      }
      return .invalid(
        value,
        error: error.asTheError()
      )
    }

    let validatedJSON: Validated<JSON> =
      try await self.update { (resource: inout Resource) in
        resource[keyPath: field] = jsonValue
      }
      .validator(for: field).validate(jsonValue)

    do {
      return .init(
        value: try jsonToValue(validatedJSON.value),
        error: validatedJSON.error
      )
    }
    catch {
      return .invalid(
        value,
        error: error.asTheError()
      )
    }
  }
}
