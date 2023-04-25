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
public final class DynamicVariables: @unchecked Sendable {

  @dynamicMemberLookup
  public struct VariableNames {
    public subscript(
      dynamicMember name: StaticString
    ) -> StaticString {
      name
    }
  }

  private final class Value {

    fileprivate let type: Any.Type
    private let name: StaticString
    private var value: Any

    fileprivate init<Value>(
      name: StaticString,
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

    fileprivate func set<Value>(
      _ value: Value
    ) {
      self.value = value
    }
  }

  private let state: CriticalState<Dictionary<StaticString, Value>> = .init(.init())
  private let variableNames: VariableNames = .init()
  private var values: Dictionary<StaticString, Value> {
    get { self.state.get(\.self) }
    set { self.state.set(\.self, newValue) }
  }

  public init() {}

  public subscript<Variable>(
    dynamicMember name: StaticString
  ) -> Variable {
    get {
      switch self.values[name] {
      case let .some(variable):
        return variable.get(Variable.self)

      case .none:
        fatalError("Undefined variable \"\(name)\" of type: \(Variable.self)")
      }
    }
    set {
      if let value: Value = self.values[name] {
        value.set(newValue)
      }
      else {
        self.values[name] = .init(
          name: name,
          value: newValue
        )
      }
    }
  }

  public func get<Variable>(
    _ member: KeyPath<DynamicVariables.VariableNames, StaticString>,
    of type: Variable.Type = Variable.self
  ) -> Variable {
    return self[dynamicMember: self.variableNames[keyPath: member]]
  }

  public func getIfPresent<Variable>(
    _ member: KeyPath<DynamicVariables.VariableNames, StaticString>,
    of type: Variable.Type = Variable.self
  ) -> Optional<Variable> {
    if self.contains(member, of: type) {
      return self[dynamicMember: self.variableNames[keyPath: member]]
    }
    else {
      return .none
    }
  }

  public func set<Value>(
    _ member: KeyPath<DynamicVariables.VariableNames, StaticString>,
    of type: Value.Type = Value.self,
    to value: Value
  ) {
    self[dynamicMember: self.variableNames[keyPath: member]] = value
  }

  public func clear(
    _ member: KeyPath<DynamicVariables.VariableNames, StaticString>
  ) {
    let name: StaticString = self.variableNames[keyPath: member]
    self.values[name] = .none
  }

  public func contains<Value>(
    _ member: KeyPath<DynamicVariables.VariableNames, StaticString>,
    of type: Value.Type = Value.self
  ) -> Bool {
    let name: StaticString = self.variableNames[keyPath: member]
    return self.values[name]?.type == type
  }
}
