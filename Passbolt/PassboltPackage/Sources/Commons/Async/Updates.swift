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

  @usableFromInline internal typealias Generation = UpdatesSource.Generation

  @usableFromInline internal var generation: Generation
  @usableFromInline internal let check: @Sendable () -> Generation?
  @usableFromInline internal let next: @Sendable (inout Generation) async -> Void?

  public init(
    for source: UpdatesSource
  ) {
    self.generation = 0  // always deliver at least first/lastelement if able
    self.check = { @Sendable [weak source] () -> Generation? in
      source?.generation
    }
    self.next = { @Sendable [weak source] (generation: inout Generation) async -> Void? in
      await source?.update(after: &generation)
    }
  }

  public init(
    combined lSource: Updates,
    with rSource: Updates
  ) {
    self.generation = 0  // always deliver at least first/last element if able
    self.check = { @Sendable [lSource, rSource] () -> Generation? in
      switch (lSource.check(), rSource.check()) {
      case (.some(let lGeneration), .some(let rGeneration)):
        return Swift.max(lGeneration, rGeneration)

      case (.some(let generation), .none):
        return generation

      case (.none, .some(let generation)):
        return generation

      case (.none, .none):
        return .none
      }
    }
    self.next = { @Sendable [lSource, rSource] (generation: inout UpdatesSource.Generation) async -> Void? in
      let requested: Generation = generation
      let recieved: Optional<Generation> = await withTaskGroup(of: Optional<Generation>.self) {
        (group: inout TaskGroup<Optional<Generation>>) in
        group.addTask {
          var generation: Generation = requested
          if case .some = await lSource.next(&generation) {
            return generation
          }
          else {
            return .none
          }
        }

        group.addTask {
          var generation: Generation = requested
          if case .some = await rSource.next(&generation) {
            return generation
          }
          else {
            return .none
          }
        }

        if case .some(.some(let first)) = await group.next() {
          group.cancelAll()
          return first
        }
        else if case .some(.some(let second)) = await group.next() {
          return second
        }
        else {
          return .none
        }
      }

      if Task.isCancelled {
        // do not update local generation on cancelled
        return .none
      }
      else if let recieved {
        generation = recieved
        return Void()
      }
      else {
        generation = .max
        return .none
      }
    }
  }

  private init() {
    self.generation = .max
    self.check = { () -> UpdatesSource.Generation? in
      .none
    }
    self.next = { @Sendable (_: inout UpdatesSource.Generation) async -> Void? in
      .none
    }
  }

  @_transparent
  public func hasUpdate() -> Bool {
    let current: UpdatesSource.Generation = self.check() ?? .max
    return current > self.generation
  }

  @_transparent
  @discardableResult
  public mutating func checkUpdate() -> Bool {
    let current: UpdatesSource.Generation = self.check() ?? .max
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

  //  @_transparent
  @discardableResult
  public mutating func next() async -> Void? {
    // no source or max is the same as finished
    guard self.generation != .max
    else { return .none }  // there won't be any new updates
    return await self.next(&self.generation)
  }

  @_transparent
  public func makeAsyncIterator() -> Self {
    self
  }
}

extension Updates {

  public var publisher: UpdatesPublisher {
    .init(for: self)
  }
}
