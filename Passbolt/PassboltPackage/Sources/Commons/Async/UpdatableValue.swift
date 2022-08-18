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

public final actor UpdatableValue<Value> {

  private var lastValue: Value? = .none
  private var pendingUpdate: Task<Value, Error>?
  private let update: @Sendable () async throws -> Value
  private nonisolated let updatesSequence: UpdatesSequence
  private var updatesGeneration: UpdatesSequence.Generation

  public init(
    initial: Value? = .none,
    updatesSequence: UpdatesSequence,
    update: @escaping @Sendable () async throws -> Value
  ) {
    self.lastValue = initial
    // skip initial update if initial value was provided
    self.updatesGeneration = initial == nil ? 0 : 1
    self.update = update
    self.updatesSequence = updatesSequence
  }
}

extension UpdatableValue {

  public var value: Value {
    get async throws {
      do {
        // check for an update
        self.updatesGeneration = try self.updatesSequence.checkUpdate(after: self.updatesGeneration)
      }
      // NoUpdate is thrown immediately if
      // there was no new update
      catch is NoUpdate {
        if let pendingUpdate: Task<Value, Error> = self.pendingUpdate {
          return try await pendingUpdate.value
        }
        else if let value: Value = self.lastValue {
          return value
        }
        else {
          return try await requestUpdate()
        }
      }
      catch let error as CancellationError {
        throw error
      }
      catch {
        // it should be only cancellation
        assertionFailure("Unexpected error: \(error)")
        throw error
      }
      #warning("To verify if we should wait for the previous update to finish")
      if let pendingUpdate: Task<Value, Error> = self.pendingUpdate {
        await pendingUpdate.waitForCompletion()
      }
      else {
        /* NOP */
      }
      // if there was an update request new value
      return try await requestUpdate()
    }
  }

  private func requestUpdate() async throws -> Value {
    let pendingUpdate: Task<Value, Error> =
      .init(operation: self.update)

    self.pendingUpdate = pendingUpdate
    defer { self.pendingUpdate = .none }

    let updatedValue: Value = try await pendingUpdate.value
    self.lastValue = updatedValue
    return updatedValue
  }
}

extension UpdatableValue: AsyncSequence {

  public typealias Element = Value
  public typealias AsyncIterator = AnyAsyncIterator<Value>

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    self.updatesSequence
      .map { try await self.value }
      .makeAsyncIterator()
      .asAnyAsyncIterator()
  }
}
