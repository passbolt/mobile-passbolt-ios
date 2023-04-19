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

public struct Awaiter<Value> {

  public let id: IID
  #if DEBUG
  @usableFromInline internal let continuation: CheckedContinuation<Value, Error>?

  @usableFromInline
  internal init(
    id: IID,
    continuation: CheckedContinuation<Value, Error>?
  ) {
    self.id = id
    self.continuation = continuation
  }
  #else
  @usableFromInline internal let continuation: UnsafeContinuation<Value, Error>?

  @usableFromInline
  internal init(
    id: IID,
    continuation: UnsafeContinuation<Value, Error>?
  ) {
    self.id = id
    self.continuation = continuation
  }
  #endif

  @inlinable
  public func resume(
    returning value: Value
  ) {
    self.continuation?
      .resume(returning: value)
  }

  @inlinable
  public func resume(
    throwing error: Error
  ) {
    self.continuation?
      .resume(throwing: error)
  }
}

extension Awaiter {

  @inlinable
  public static func withCancelation(
    _ cancelation: @escaping @Sendable (IID) -> Void,
    id: IID = .init(),
    execute: @escaping (Awaiter) -> Void
  ) async throws -> Value {
    try await withTaskCancellationHandler(
      operation: {
        #if DEBUG
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, Error>) in
          execute(
            Awaiter(
              id: id,
              continuation: continuation
            )
          )
          if Task.isCancelled {
            cancelation(id)
          } // else NOP
        }
        #else
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Value, Error>) in
          execute(
            Awaiter(
              id: id,
              continuation: continuation
            )
          )
          if Task.isCancelled {
            cancelation(id)
          } // else NOP
        }
        #endif
      },
      onCancel: {
        cancelation(id)
      }
    )
  }
}

extension Awaiter: Sendable {}

extension Awaiter: Equatable {

  public static func == (
    _ lhs: Awaiter,
    _ rhs: Awaiter
  ) -> Bool {
    lhs.id == rhs.id
  }
}

extension Awaiter: Hashable {

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.id)
  }
}

extension Swift.Set {

  @inlinable
  internal func contains<Value>(
    awaiter: Awaiter<Value>
  ) -> Bool
  where Self.Element == Awaiter<Value> {
    self.contains(awaiter)
  }

  @inlinable
  internal mutating func removeAwaiter<Value>(
    withID awaiterID: IID
  ) -> Awaiter<Value>?
  where Self.Element == Awaiter<Value> {
    guard
      let index: Self.Index = self.firstIndex(
        of: .init(
          id: awaiterID,
          continuation: .none
        )
      )
    else { return .none }
    return self.remove(at: index)
  }
}
