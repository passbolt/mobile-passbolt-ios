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
  public var state: any DataSource<Resource>
  // Change the resource type
  public var updateType: @Sendable (ResourceType) throws -> Void
  // Validate form state
  public var validateForm: @Sendable () async throws -> Void
  // Send the form
  public var sendForm: @Sendable () async throws -> Resource
  // Update resource, publicly exposing only dedicated methods
  // in order to avoid mutable access to the whole resource
  internal var updateField: @Sendable (Resource.FieldPath, JSON) -> Validated<JSON>

  public init(
    state: any DataSource<Resource>,
    updateField: @escaping @Sendable (Resource.FieldPath, JSON) -> Validated<JSON>,
    updateType: @escaping @Sendable (ResourceType) throws -> Void,
    validateForm: @escaping @Sendable () async throws -> Void,
    sendForm: @escaping @Sendable () async throws -> Resource
  ) {
    self.state = state
    self.updateField = updateField
    self.updateType = updateType
    self.validateForm = validateForm
    self.sendForm = sendForm
  }
}

extension ResourceEditForm: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Self {
    .init(
      state: PlaceholderDataSource(),
      updateField: unimplemented2(),
      updateType: unimplemented1(),
      validateForm: unimplemented0(),
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
    self.updateField(field, value)
  }

  @discardableResult
  @Sendable public func update(
    _ field: Resource.FieldPath,
    to value: String
  ) -> Validated<String> {
    self.updateField(field, .string(value))
      .map { $0.stringValue ?? "" }
  }

  @discardableResult
  @Sendable public func update(
    _ field: Resource.FieldPath,
    to value: Int
  ) -> Validated<Int> {
    self.updateField(field, .integer(value))
      .map { $0.intValue ?? 0 }
  }

  @discardableResult
  @Sendable public func update<Raw>(
    _ field: Resource.FieldPath,
    to value: Raw
  ) -> Validated<Raw?>
  where Raw: RawRepresentable, Raw.RawValue == String {
    self.updateField(field, .string(value.rawValue))
      .map { Raw(rawValue: $0.stringValue ?? "") }
  }

  @discardableResult
  @Sendable public func update(
    _ field: Resource.FieldPath,
    to value: TOTPSecret
  ) -> Validated<TOTPSecret?> {
    self.updateField(field, value.asJSON)
      .map { $0.totpSecretValue }
  }
}
