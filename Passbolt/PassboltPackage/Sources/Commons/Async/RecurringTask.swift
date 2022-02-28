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

  private var runningTask: Task<Void, Never>?
  private var operation: @Sendable () async -> Void

  public init() {
    self.runningTask = nil
    self.operation = {}
  }

  public convenience init(
    priority: TaskPriority? = nil,
    runImmediately: Bool = true,
    operation: @Sendable @escaping () async -> Void
  ) {
    self.init()
    if runImmediately {
      Task {
        await self.run(
          replacingCurrent: true,
          priority: priority,
          operation
        )
      }
    }
    else {
      Task {
        await self.setOperation(operation)
      }
    }
  }

  deinit {
    self.cancel()
  }

  public func run(
    replacingCurrent: Bool = true,
    priority: TaskPriority? = nil
  ) async {
    guard self.runningTask == nil || replacingCurrent else { return }
    self.runningTask?.cancel()
    self.runningTask = Task(
      priority: priority,
      operation: self.operation
    )
    await self.runningTask?.value
  }

  public func run(
    replacingCurrent: Bool = true,
    priority: TaskPriority? = nil,
    _ operation: @Sendable @escaping () async -> Void
  ) async {
    self.setOperation(operation)
    guard self.runningTask == nil || replacingCurrent else { return }
    self.runningTask?.cancel()
    self.runningTask = Task(
      priority: priority,
      operation: self.operation
    )
    await self.runningTask?.value
  }

  public func cancel() {
    self.runningTask?.cancel()
    self.runningTask = nil
  }

  private func setOperation(
    _ operation: @Sendable @escaping () async -> Void
  ) {
    self.operation = {
      guard !Task.isCancelled
      else { return await self.completeTask() }
      await operation()
      await self.completeTask()
    }
  }

  private func completeTask() {
    self.runningTask = nil
  }
}
