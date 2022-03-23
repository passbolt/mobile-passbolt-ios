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

public final actor ManagedTask<Success> {

  private var currentTask: Task<Success, Error>? = .none

  public init() {
    self.currentTask = .none
  }

  deinit {
    self.currentTask?.cancel()
  }

  public func run(
    replacingCurrent: Bool = false,
    priority: TaskPriority? = nil,
    _ operation: @escaping () async throws -> Success
  ) async throws -> Success {
    if let runningTask: Task<Success, Error> = self.currentTask, !runningTask.isCancelled {
      if replacingCurrent {
        runningTask.cancel()
        // it will continue to running new task
      }
      else {
        return try await runningTask.value
      }
    }
    else { /* continue */
    }

    let newTask: Task<Success, Error> = Task(
      priority: priority,
      operation: { try await operation() }
    )

    self.currentTask = newTask
    do {
      let result: Success = try await newTask.value
      self.currentTask = .none
      return result
    }
    catch {
      if !newTask.isCancelled {
        self.currentTask = .none
      }
      else { /* NOP */
      }
      throw error
    }
  }

  public func cancel() {
    self.currentTask?.cancel()
  }
}
