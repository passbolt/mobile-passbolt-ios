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

public struct LegacyResourceEditForm {

  // Form state updates
  public var updates: Updates
  // Access current resource state
  public var resource: @Sendable () async throws -> Resource
  // Access list of all available fields for edited resource
  public var fieldsPublisher: @Sendable () -> AnyPublisher<OrderedSet<ResourceFieldSpecification>, Never>
  // Assign value for given field
  public var setFieldValue: @Sendable (JSON, Resource.FieldPath) async throws -> Void
  // Publisher for validated values for given field
  public var validatedFieldValuePublisher: @Sendable (Resource.FieldPath) -> AnyPublisher<Validated<JSON>, Never>
  // Send the form
  public var sendForm: @Sendable () async throws -> Resource.ID

  public init(
    updates: Updates,
    resource: @escaping @Sendable () async throws -> Resource,
    fieldsPublisher: @escaping @Sendable () -> AnyPublisher<OrderedSet<ResourceFieldSpecification>, Never>,
    setFieldValue: @escaping @Sendable (JSON, Resource.FieldPath) async throws -> Void,
    validatedFieldValuePublisher: @escaping @Sendable (Resource.FieldPath) -> AnyPublisher<Validated<JSON>, Never>,
    sendForm: @escaping @Sendable () async throws -> Resource.ID
  ) {
    self.updates = updates
    self.resource = resource
    self.fieldsPublisher = fieldsPublisher
    self.setFieldValue = setFieldValue
    self.validatedFieldValuePublisher = validatedFieldValuePublisher
    self.sendForm = sendForm
  }
}

extension LegacyResourceEditForm: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: LegacyResourceEditForm {
    Self(
      updates: .placeholder,
      resource: unimplemented0(),
      fieldsPublisher: unimplemented0(),
      setFieldValue: unimplemented2(),
      validatedFieldValuePublisher: unimplemented1(),
      sendForm: unimplemented0()
    )
  }
  #endif
}
