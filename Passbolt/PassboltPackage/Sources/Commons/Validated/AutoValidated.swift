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

import struct OrderedCollections.OrderedDictionary

@dynamicMemberLookup
public struct AutoValidated<State> {

  public private(set) var state: State
  private var validations: OrderedDictionary<PartialKeyPath<State>, Validation<State>>

  public init(
    state: State,
    _ validations: Validation<State>...
  ) {
    self.state = state
    self.validations = .init()
    self.validations.reserveCapacity(validations.count)
    for validation: Validation<State> in validations {
      self.validations[validation.keyPath] = validation
    }
  }

  @_disfavoredOverload
  public subscript<Value>(
    dynamicMember keyPath: KeyPath<State, Value>
  ) -> Value {
    self.state[keyPath: keyPath]
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<State, Validated<Value>>
  ) -> Value {
    get {
      self.state[keyPath: keyPath].value
    }
    set {
      self.state[keyPath: keyPath].value = newValue
      guard let validation: Validation<State> = self.validations[keyPath]
      else { return }  // else no validation used
      validation.validate(&self.state)
    }
  }
}

extension AutoValidated {

  public mutating func validate() throws {
    for validation: Validation<State> in self.validations.values {
      if let error = validation.validate(&self.state) {
        throw error
      }
      else {
        continue
      }
    }
  }

  public mutating func apply(
    _ assignment: Assignment<State>
  ) {
    assignment.assign(on: &self.state)
    guard let validation: Validation<State> = self.validations[assignment.keyPath]
    else { return }  // else no validation used
    validation.validate(&self.state)
  }

  public mutating func set<Value>(
    validator: Validator<Value>,
    for keyPath: WritableKeyPath<State, Validated<Value>>
  ) {
    self.validations[keyPath] = .validating(
      keyPath,
      with: validator
    )
  }

  public mutating func append<Value>(
    validator: Validator<Value>,
    for keyPath: WritableKeyPath<State, Validated<Value>>
  ) {
    if let validation: Validation<State> = self.validations[keyPath] {
      self.validations[keyPath] = .combine(
        validation,
        .validating(
          keyPath,
          with: validator
        ),
        for: keyPath
      )
    }
    else {
      self.validations[keyPath] = .validating(
        keyPath,
        with: validator
      )
    }
  }

  public mutating func removeValidation<Value>(
    for keyPath: WritableKeyPath<State, Validated<Value>>
  ) {
    self.validations[keyPath] = .none
  }
}
