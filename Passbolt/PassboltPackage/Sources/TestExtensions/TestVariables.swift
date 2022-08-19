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

@dynamicMemberLookup
public struct TestVariables: @unchecked Sendable {

  public struct VariableName: Hashable, CustomStringConvertible {

    fileprivate var rawValue: StaticString

    internal init(rawValue: StaticString) {
      self.rawValue = rawValue
    }

    public var description: String {
      "\(self.rawValue)"
    }
  }

  private struct Variable {

    fileprivate let type: Any.Type
    private let name: VariableName
    private var value: Any

    fileprivate init<Value>(
      name: VariableName,
      value: Value
    ) {
      self.type = Value.self
      self.name = name
      self.value = value
    }

    fileprivate func get<Value>(
      _ type: Value.Type
    ) -> Value {
      switch self.value {
      case let value as Value:
        return value

      case let value as Optional<Value>:
        switch value {
        case let .some(value):
          return value

        case .none:
          fatalError(
            "Invalid variable: \"\(self.name)\", type: \(self.type), expected type: \(Value.self), value: \(value as Any)"
          )
        }

      case _:
        fatalError(
          "Invalid variable: \"\(self.name)\", type: \(self.type), expected type: \(Value.self), value: \(value as Any)"
        )

      }
    }

    fileprivate mutating func set<Value>(
      _ value: Value
    ) {
      self.value = value
    }
  }

  private let state: CriticalState<Dictionary<VariableName, Variable>> = .init(.init())

  private var values: Dictionary<VariableName, Variable> {
    get { self.state.get(\.self) }
    set { self.state.set(\.self, newValue) }
  }

  public init() {}

  public subscript(
    dynamicMember name: StaticString
  ) -> VariableName {
    get { .init(rawValue: name) }
  }

  public func get<Value>(
    _ member: KeyPath<TestVariables, VariableName>,
    of type: Value.Type = Value.self
  ) -> Value {
    let name: VariableName = self[keyPath: member]
    switch self.values[name] {
    case let .some(variable):
      return variable.get(Value.self)

    case .none:
      fatalError("Undefined variable \"\(name)\" of type: \(Value.self)")
    }
  }

  public mutating func set<Value>(
    _ member: KeyPath<TestVariables, VariableName>,
    of type: Value.Type = Value.self,
    to value: Value
  ) {
    let name: VariableName = self[keyPath: member]
    self.values[name] = .init(
      name: name,
      value: value
    )
  }

  public mutating func clear(
    _ member: KeyPath<TestVariables, VariableName>
  ) {
    self.values[self[keyPath: member]] = .none
  }

  public func contains<Value>(
    _ member: KeyPath<TestVariables, VariableName>,
    of type: Value.Type = Value.self
  ) -> Bool {
    self.values[self[keyPath: member]]?.type == type
  }
}
