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

public struct Updates: Sendable {

  #if DEBUG
  public static let placeholder: Self = .init()
  #endif
  public static let never: Self = .init()

  @usableFromInline internal var generation: UpdatesSource.Generation
  @usableFromInline internal private(set) weak var updatesSource: UpdatesSource?

  public init(
    for source: UpdatesSource
  ) {
    self.generation = 0  // always deliver at least first/lastelement if able
    self.updatesSource = source
  }

  private init() {
    self.generation = .max
    self.updatesSource = .none
  }

  @_transparent
  public func hasUpdate() -> Bool {
    let current: UpdatesSource.Generation = self.updatesSource?.state.get(\.generation) ?? .max
    return current > self.generation
  }

  @_transparent
  @discardableResult
  public mutating func checkUpdate() -> Bool {
    let current: UpdatesSource.Generation = self.updatesSource?.state.get(\.generation) ?? .max
    if current > self.generation {
      self.generation = current
      return true
    }
    else {
      return false
    }
  }
}

extension Updates: AsyncSequence, AsyncIteratorProtocol {

  public typealias Element = Void
  public typealias AsyncIterator = Self

  @_transparent
  @discardableResult
  public mutating func next() async -> Void? {
    await self.updatesSource?.update(after: &self.generation)
  }

  @_transparent
  public func makeAsyncIterator() -> Self {
    self
  }
}

extension Updates {

  public var publisher: UpdatesPublisher {
    if let updatesSource {
      return .init(for: .init(for: updatesSource))
    }
    else {
      return .init(for: .init())
    }
  }
}
