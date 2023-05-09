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

@Sendable public func future<Value>(
  _ fulfill: @escaping (@Sendable @escaping (Result<Value, Error>) -> Void) -> Void
) async throws -> Value {
  let state: CriticalState<CheckedContinuation<Value, Error>?> = .init(.none)
  return try await withTaskCancellationHandler(
    operation: {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, Error>) in
        guard !Task.isCancelled
        else {
          return
            continuation
            .resume(throwing: Cancelled.error())
        }
        state
          .set(\.self, continuation)

        fulfill { (result: Result<Value, Error>) in
          state
            .exchange(\.self, with: .none)?
            .resume(with: result)
        }
      }
    },
    onCancel: {
      state
        .exchange(\.self, with: .none)?
        .resume(throwing: Cancelled.error())
    }
  )
}
