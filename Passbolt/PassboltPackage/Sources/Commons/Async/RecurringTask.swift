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

public final actor RecurringTask {

  private let taskPriority: TaskPriority?
  private var operation: @Sendable () async -> Void
  private var currentTask: Task<Void, Never>?

  public init(
    priority: TaskPriority? = nil,
    operation: @Sendable @escaping () async -> Void = {}
  ) {
    self.taskPriority = priority
    self.operation = operation
    self.currentTask = .none
  }

  deinit {
    self.currentTask?.cancel()
  }

  public func run(
    replacingCurrent: Bool = true
  ) async {
    if let runningTask: Task<Void, Never> = self.currentTask, !runningTask.isCancelled {
      if replacingCurrent {
        runningTask.cancel()
        // it will continue to running new task
      }
      else {
        return await runningTask.value
      }
    }
    else { /* continue */
    }

    let newTask: Task<Void, Never> = Task(
      priority: self.taskPriority,
      operation: self.operation
    )

    self.currentTask = newTask
    await newTask.value

    if !newTask.isCancelled {
      self.currentTask = .none
    }
    else { /* NOP */
    }
  }

  public func cancel() {
    self.currentTask?.cancel()
  }
}
