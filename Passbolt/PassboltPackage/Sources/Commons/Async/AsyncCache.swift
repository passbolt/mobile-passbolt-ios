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

public final actor AsyncCache<Value> {

  private enum State {
    case empty
    case pending(Task<Value, Error>)
    case value(Value)
  }

  private var state: State

  public init(
    value: Value? = .none
  ) {
    if let initialValue: Value = value {
      self.state = .value(initialValue)
    }
    else {
      self.state = .empty
    }
  }

  public var value: Value? {
    get async {
      switch self.state {
      case .empty:
        return .none

      case let .pending(task):
        return try? await task.value

      case let .value(value):
        return value
      }
    }
  }

  @discardableResult
  public func update(
    _ task: @escaping () async throws -> Value
  ) async throws -> Value {
    switch self.state {
    case .empty, .value:
      break

    case let .pending(task):
      task.cancel()
    }

    let updateTask: Task<Value, Error> = Task {
      let value: Value = try await task()
      try Task.checkCancellation()
      return value
    }

    self.state = .pending(updateTask)

    do {
      let updatedValue: Value = try await updateTask.value

      self.state = .value(updatedValue)

      return updatedValue
    }
    catch {
      self.state = .empty
      throw error
    }
  }

  public func valueOrUpdate(
    _ task: @escaping () async throws -> Value
  ) async throws -> Value {
    switch self.state {
    case .empty:
      return try await self.update(task)

    case let .pending(pendingTask):
      do {
        return try await pendingTask.value
      }
      catch {
        return try await self.update(task)
      }

    case let .value(value):
      return value
    }
  }
}
