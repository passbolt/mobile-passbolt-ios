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

  public var updates: UpdatesSequence
  public var state: @Sendable () -> State
  public var update: @Sendable (Assignment<State>) -> Void
  public var sendForm: @Sendable () async throws -> Void

  public init(
    updates: UpdatesSequence,
    state: @escaping @Sendable () -> State,
    update: @escaping @Sendable (Assignment<State>) -> Void,
    sendForm: @escaping @Sendable () async throws -> Void
  ) {
    self.updates = updates
    self.state = state
    self.update = update
    self.sendForm = sendForm
  }
}

extension ResourceEditForm {

  public typealias State = Resource

  public func update(
    field: ResourceField,
    to value: ResourceFieldValue
  ) {
    self.update(.assigning(value, to: State.keyPath(for: field)))
  }

  public func update<Value>(
    field keyPath: WritableKeyPath<State, Value>,
    to value: Value
  ) {
    self.update(.assigning(value, to: keyPath))
  }

  public func update<Value>(
    field keyPath: WritableKeyPath<State, Validated<Value>>,
    toValidated value: Value
  ) {
    self.update(.assigning(value, toValidated: keyPath))
  }
}

extension ResourceEditForm: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Self {
    .init(
      updates: .placeholder,
      state: unimplemented0(),
      update: unimplemented1(),
      sendForm: unimplemented0()
    )
  }
  #endif
}
