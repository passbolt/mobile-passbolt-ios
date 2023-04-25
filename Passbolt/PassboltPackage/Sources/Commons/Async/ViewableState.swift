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

  private typealias Generation = MutableState<Value>.Generation
  private typealias Reader = @Sendable (inout Generation) async throws -> Value
  private typealias Awaiter = @Sendable (Result<Value, Error>) -> Void

  private let current: Reader

  public init(
    viewing: MutableState<Value>
  ) {
    self.current = viewing.current(including:)
  }
}

extension ViewableState: Sendable {}

extension ViewableState {

  public var value: Value {
    get async throws {
      var generation: Generation = 0 // 0 guarantees receiving latest value
      return try await self.current(&generation)
    }
  }
}

extension ViewableState: AsyncSequence {

  public typealias Element = Value
  public struct AsyncIterator: AsyncIteratorProtocol {

    public typealias Element = Value

    private var generation: Generation = 1
    private var requestNext: @Sendable (inout Generation) async throws -> Element

    fileprivate init(
      _ state: ViewableState<Element>
    ) {
      self.requestNext = state.current
    }

    public mutating func next() async throws -> Value? {
      defer {
        // it has to be one generation ahead to avoid infinite loop
        // because of usage of MutableState.current(including:)
        self.generation &+= 1
      }
      return try await self.requestNext(&self.generation)
    }
  }

  public nonisolated func makeAsyncIterator() -> AsyncIterator {
    .init(self)
  }
}

extension ViewableState {

  #if DEBUG
  public static var placeholder: Self {
    .init(viewing: .placeholder)
  }
  #endif
}
