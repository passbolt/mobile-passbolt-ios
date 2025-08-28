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

public actor SerialDatabaseOperationExecutor<OperationDescription>
where OperationDescription: DatabaseOperationDescription {

  private let operation: DatabaseOperation<OperationDescription>
  private var lastTask: Task<Void, Never> = Task {}  // Initial empty task

  public init(_ operation: DatabaseOperation<OperationDescription>) {
    self.operation = operation
  }

  public func execute(
    _ input: OperationDescription.Input
  ) async throws -> OperationDescription.Output {
    // Chain the new operation after the last one
    let currentTask = lastTask
    let task = Task<OperationDescription.Output, Error> {
      // Wait for previous operation to finish
      await currentTask.value
      // Execute this operation
      return try await operation(input)
    }
    // Update the lastTask to this one (ignoring result)
    lastTask = Task { _ = try? await task.value }
    return try await task.value
  }
}

extension SerialDatabaseOperationExecutor where OperationDescription.Input == Void {

  public func execute() async throws -> OperationDescription.Output {
    try await execute(())
  }
}
