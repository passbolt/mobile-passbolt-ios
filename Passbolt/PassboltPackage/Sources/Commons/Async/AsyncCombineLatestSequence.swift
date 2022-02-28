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

// Combine values of multiple async sequences.
public struct AsyncCombineLatestSequence<Element> {

  private let makeIterator: () -> AnyAsyncIterator<Element>

  public init<LSequence, RSequence>(
    buffering: Buffering = .unbounded,
    _ lSequence: LSequence,
    _ rSequence: RSequence
  ) where LSequence: AsyncSequence, RSequence: AsyncSequence, Element == (LSequence.Element, RSequence.Element) {
    self.makeIterator = {
      let lIterator: AnyAsyncIterator<LSequence.Element> =
        lSequence
        .makeAsyncIterator()
        .asAnyAsyncIterator()
      let rIterator: AnyAsyncIterator<RSequence.Element> =
        rSequence
        .makeAsyncIterator()
        .asAnyAsyncIterator()

      let buffer: CombinedBuffer<LSequence.Element, RSequence.Element> =
        .init(
          buffering: buffering,
          lIterator: lIterator,
          rIterator: rIterator
        )

      return AnyAsyncIterator(
        nextElement: buffer.nextValue
      )
    }
  }
}

extension AsyncCombineLatestSequence {

  public enum Buffering {
    case latest
    case unbounded
  }
}

extension AsyncCombineLatestSequence: AsyncSequence {

  public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
    self.makeIterator()
  }
}

private final actor CombinedBuffer<LValue, RValue> {

  private var lState: IteratorState<LValue>
  private var rState: IteratorState<RValue>
  private var nextAwaiter: CheckedContinuation<(LValue, RValue)?, Never>?
  private var buffer: Array<(LValue, RValue)> = .init()
  private let buffering: AsyncCombineLatestSequence<(LValue, RValue)>.Buffering

  fileprivate init(
    buffering: AsyncCombineLatestSequence<(LValue, RValue)>.Buffering,
    lIterator: AnyAsyncIterator<LValue>,
    rIterator: AnyAsyncIterator<RValue>
  ) {
    self.buffering = buffering
    self.lState = .initial(lIterator)
    self.rState = .initial(rIterator)
  }

  deinit {
    switch lState {
    case .initial, .idle, .finished:
      break

    case let .waiting(task, _), let .updating(_, task, _):
      task.cancel()
    }
    switch rState {
    case .initial, .idle, .finished:
      break

    case let .waiting(task, _), let .updating(_, task, _):
      task.cancel()
    }
    self.nextAwaiter?.resume(returning: .none)
  }

  fileprivate func nextValue() async -> (LValue, RValue)? {
    if self.finished {
      return nil
    }
    else if self.buffer.isEmpty {
      return await withCheckedContinuation { (continuation: CheckedContinuation<(LValue, RValue)?, Never>) in
        assert(self.nextAwaiter == nil, "Cannot replace awaiters")
        self.nextAwaiter = continuation
        self.requestNextValue()
      }
    }
    else {
      return self.buffer.removeFirst()
    }
  }

  private var finished: Bool {
    switch (self.lState, self.rState) {
    case (.finished, .finished), (.finished(.none), _), (_, .finished(.none)):
      return true

    case _:
      return false
    }
  }

  private func update(lValue: LValue?) async {
    if let updatedValue: LValue = lValue {
      switch self.lState {
      case let .initial(iterator), let .waiting(_, iterator), let .updating(_, _, iterator), let .idle(_, iterator):
        self.lState = .idle(updatedValue, iterator)

      case .finished:
        assertionFailure("Invalid state")
        return  // end processing
      }

      switch self.rState {
      case let .updating(rValue, _, _), let .idle(rValue, _), let .finished(.some(rValue)):
        self.handleNext((updatedValue, rValue))

      case .initial, .waiting, .finished:
        break
      }
    }
    else {
      switch self.lState {
      case .finished:
        assertionFailure("Invalid state")
        return  // end processing

      case .initial, .waiting:
        self.lState = .finished(.none)

      case let .updating(lastValue, _, _), let .idle(lastValue, _):
        self.lState = .finished(lastValue)
      }

      if self.finished {
        self.nextAwaiter?.resume(returning: nil)
        self.nextAwaiter = nil
      }
      else {
        /* NOP */
      }
    }
  }

  private func update(rValue: RValue?) async {
    if let updatedValue: RValue = rValue {
      switch self.rState {
      case let .initial(iterator), let .waiting(_, iterator), let .updating(_, _, iterator), let .idle(_, iterator):
        self.rState = .idle(updatedValue, iterator)

      case .finished:
        assertionFailure("Invalid state")
        return  // end processing
      }

      switch self.lState {
      case let .updating(lValue, _, _), let .idle(lValue, _), let .finished(.some(lValue)):
        self.handleNext((lValue, updatedValue))

      case .initial, .waiting, .finished:
        break
      }
    }
    else {
      switch self.rState {
      case .finished:
        assertionFailure("Invalid state")
        return  // end processing

      case .initial, .waiting:
        self.rState = .finished(.none)

      case let .updating(lastValue, _, _), let .idle(lastValue, _):
        self.rState = .finished(lastValue)
      }

      if self.finished {
        self.nextAwaiter?.resume(returning: nil)
        self.nextAwaiter = nil
      }
      else {
        /* NOP */
      }
    }
  }

  private func requestNextValue() {
    assert(!self.finished, "Cannot request new values when finished")
    switch self.lState {
    case let .initial(iterator):
      self.lState = .waiting(
        Task {
          let nextValue: LValue? = await iterator.next()
          await self.update(lValue: nextValue)
          return nextValue
        },
        iterator
      )

    case let .idle(value, iterator):
      self.lState = .updating(
        value,
        Task {
          let nextValue: LValue? = await iterator.next()
          await self.update(lValue: nextValue)
          return nextValue
        },
        iterator
      )

    case .waiting, .updating, .finished:
      break
    }
    switch self.rState {
    case let .initial(iterator):
      self.rState = .waiting(
        Task {
          let nextValue: RValue? = await iterator.next()
          await self.update(rValue: nextValue)
          return nextValue
        },
        iterator
      )

    case let .idle(value, iterator):
      self.rState = .updating(
        value,
        Task {
          let nextValue: RValue? = await iterator.next()
          await self.update(rValue: nextValue)
          return nextValue
        },
        iterator
      )

    case .waiting, .updating, .finished:
      break
    }
  }

  private func handleNext(_ value: (LValue, RValue)) {
    if let awaiter = self.nextAwaiter {
      awaiter.resume(returning: value)
      self.nextAwaiter = nil
    }
    else {
      switch self.buffering {
      case .unbounded:
        self.buffer.append(value)

      case .latest:
        self.buffer = [value]
      }
    }
  }
}

extension CombinedBuffer {

  private enum IteratorState<Value> {
    case initial(AnyAsyncIterator<Value>)
    case waiting(Task<Value?, Never>, AnyAsyncIterator<Value>)
    case updating(Value, Task<Value?, Never>, AnyAsyncIterator<Value>)
    case idle(Value, AnyAsyncIterator<Value>)
    case finished(Value?)
  }
}
