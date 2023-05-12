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

public final class ViewableState<Value> {

  private typealias Generation = UInt64

  private let next: @Sendable (inout Generation) async throws -> Value

  public init(
    constant value: Value
  ) {
    self.next = { (generation: inout Generation) async throws -> Value in
      defer { generation = 1 }
      if generation < 1 {
        return value
      }
      else {
        return try await Task.never()
      }
    }
  }

  public init(
    failure error: Error
  ) {
    self.next = { (generation: inout Generation) async throws -> Value in
      throw error
    }
  }

  public init(
    viewing mutableState: MutableState<Value>
  ) {
    self.next = { [weak mutableState] (generation: inout Generation) async throws -> Value in
      if let mutableState {
        return try await mutableState.next(after: &generation)
      }
      else {
        throw CancellationError()
      }
    }
  }

  private init(
    next: @escaping @Sendable (inout Generation) async throws -> Value
  ) {
    self.next = next
  }
}

extension ViewableState: Sendable {}

extension ViewableState {

  public var value: Value {
    get async throws {
      var generation: Generation = .min
      return try await self.next(&generation)
    }
  }

  public var nextValue: Value {
    get async throws {
      var generation: Generation = .max
      return try await self.next(&generation)
    }
  }
}

extension ViewableState: AsyncSequence {

  public typealias Element = Value
  public typealias AsyncIterator = AnyAsyncThrowingIterator<Element>

  public func makeAsyncIterator() -> AsyncIterator {
    var generation: Generation = .min
    return .init { [weak self] () async throws -> Element? in
      return try await self?.next(&generation)
    }
  }
}

extension ViewableState {

  #if DEBUG
  public static var placeholder: Self {
    .init(next: { _ in unimplemented() })
  }
  #endif
}
