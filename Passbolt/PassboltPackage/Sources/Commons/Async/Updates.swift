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

  public static let once: Self = .init(generation: 0)
  public static let never: Self = .init(generation: .max)

  @usableFromInline internal typealias Generation = UpdatesSource.Generation
  @usableFromInline internal typealias Awaiter = @Sendable (UpdatesSource.Generation?) -> Void

  @usableFromInline internal var generation: Generation
  @usableFromInline internal let check: @Sendable () -> Generation?
  @usableFromInline internal let requestNext: @Sendable (_ after: Generation, _ deliver: @escaping Awaiter) -> Bool

  public init(
    for source: UpdatesSource
  ) {
    self.generation = 0  // always deliver at least first/last element if able
    self.check = { @Sendable [weak source] () -> Generation? in
      source?.generation
    }
    self.requestNext = { @Sendable [weak source] (generation: Generation, deliver: @escaping Awaiter) -> Bool in
      if let source {
        source.update(
          after: generation,
          deliver: deliver
        )
        return true
      }
      else {
        return false
      }
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
    self.requestNext = { @Sendable (generation: Generation, deliver: @escaping Awaiter) -> Bool in
      let lRequested: Bool = lSource.requestNext(generation, deliver)
      let rRequested: Bool = rSource.requestNext(generation, deliver)
      return lRequested || rRequested
    }
  }

  private init(
    generation: Generation
  ) {
    self.generation = generation
    self.check = { () -> Generation? in
      .none
    }
    self.requestNext = { @Sendable (generation: Generation, deliver: Awaiter) -> Bool in
      if generation == .max {
        return false
      }
      else {
        deliver(.max)
        return true
      }
    }
  }

  @_transparent
  @discardableResult
  public mutating func checkUpdate() -> Bool {
    // no source or max is the same as finished, there won't be any new updates
    guard self.generation != .max else { return false }
    let current: Generation = self.check() ?? .max
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
    // max is the same as finished, there won't be any new updates
    guard self.generation != .max else { return .none }
    let awaiter: CriticalState<UnsafeContinuation<Generation?, Never>?> = .init(.none)
    let nextGeneration: Generation? = await withTaskCancellationHandler(
      operation: { () -> Generation? in
        await withUnsafeContinuation { (continuation: UnsafeContinuation<Generation?, Never>) in
          let requestUpdate: Bool = awaiter.access { (awaiter: inout UnsafeContinuation<Generation?, Never>?) -> Bool in
            if Task.isCancelled {
              continuation
                .resume(returning: .none)
              return false
            }
            else {
              awaiter = continuation
              return true
            }
          }
          guard requestUpdate else { return }
          if self.requestNext(
            generation,
            { (generation: Generation?) in
              awaiter
                .exchange(with: .none)?
                .resume(returning: generation)
            }
          ) {
          }
          else {
            awaiter
              .exchange(with: .none)?
              .resume(returning: .none)
          }
        }
      },
      onCancel: {
        awaiter
          .exchange(with: .none)?
          .resume(returning: .none)
      }
    )

    if let nextGeneration: Generation {
      self.generation = nextGeneration
      return Void()
    }
    else {
      return .none
    }
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
