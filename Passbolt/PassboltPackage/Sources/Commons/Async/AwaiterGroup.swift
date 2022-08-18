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

public struct AwaiterGroup<Value>: Sendable {

  @usableFromInline internal let state: CriticalState<Set<Awaiter<Value>>>

  public init() {
    self.state = .init(
      .init(),
      cleanup: { state in
        for awaiter in state {
          awaiter
            .resume(
              throwing: CancellationError()
            )
        }
      }
    )
  }
}

extension AwaiterGroup {

  @inlinable
  public func awaiter() async throws -> Value {
    try await Awaiter<Value>
      .withCancelation(
        { awaiterID in
          self.state.access { state in
            let canceledAwaiter: Awaiter<Value>? =
              state
              .removeAwaiter(withID: awaiterID)

            canceledAwaiter?
              .resume(throwing: CancellationError())
          }
        },
        execute: { awaiter in
          self.state.access { state in
            assert(
              !state.contains(awaiter: awaiter),
              "Cannot reuse awaiter IDs!"
            )
            state.insert(awaiter)
          }
        }
      )
  }

  @inlinable
  public func resumeAll(
    returning value: Value
  ) {
    self.state.access { state in
      for awaiter in state {
        awaiter.resume(returning: value)
      }
      state.removeAll(keepingCapacity: true)
    }
  }

  @inlinable
  public func resumeAll(
    throwing error: Error
  ) {
    self.state.access { state in
      for awaiter in state {
        awaiter.resume(throwing: error)
      }
      state.removeAll(keepingCapacity: true)
    }
  }

  @inlinable
  public func cancelAll() {
    self.resumeAll(
      throwing: CancellationError()
    )
  }
}

extension AwaiterGroup
where Value == Void {

  @inlinable
  public func resumeAll() {
    self.resumeAll(returning: Void())
  }
}
