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

public struct Once: Sendable {

  private struct State: Sendable {

    fileprivate enum Execution: Sendable {

      case waiting(@Sendable () async -> Void)
      case inProgress(Task<Void, Never>)
      case finished
    }

    fileprivate var execution: Execution
    fileprivate var continuations: Dictionary<IID, UnsafeContinuation<Void, Error>>
  }

  private let state: CriticalState<State>

  public init(
    _ execute: @escaping @Sendable () async -> Void
  ) {
    self.state = .init(
      .init(
        execution: .waiting(execute),
        continuations: .init()
      )
    )
  }

  @Sendable public func executeIfNeeded() {
    self.state.access { (state: inout State) in
      switch state.execution {
      case .finished, .inProgress:
        return  // NOP

      case let .waiting(execute):
        state.execution = .inProgress(
          .init {
            await execute()
            self.state.access { (state: inout State) in
              state.execution = .finished
              for continuation in state.continuations.values {
                continuation.resume(returning: Void())
              }
            }
          }
        )
      }
    }
  }

  @Sendable public func waitForCompletion() async throws {
    let id: IID = .init()
    try await withTaskCancellationHandler(
      operation: {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
          self.state.access { (state: inout State) in
            if Task.isCancelled {
              continuation.resume(throwing: CancellationError())
            }
            else {
              switch state.execution {
              case .finished:
                continuation.resume(returning: Void())

              case .inProgress, .waiting:
                state.continuations[id] = continuation
              }
            }

          }
        }
      },
      onCancel: {
        self.state.access { (state: inout State) in
          state.continuations.removeValue(forKey: id)?
            .resume(throwing: CancellationError())
        }
      }
    )
  }
}
