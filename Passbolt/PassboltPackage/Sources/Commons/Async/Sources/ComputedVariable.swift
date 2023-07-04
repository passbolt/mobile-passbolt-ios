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

public final class ComputedVariable<DataValue>: DataSource
where DataValue: Sendable {

  public typealias Failure = Error

  private struct Storage: Sendable {

    fileprivate enum State: Sendable {

      case initial
      case cached(DataValue)
      case terminal(Failure?)
    }

    fileprivate var state: State
    fileprivate var sourceUpdates: Updates
    fileprivate var runningUpdate: Task<Void, Never>?
    fileprivate var awaiters: Dictionary<IID, UnsafeContinuation<DataValue, Error>>
  }

  public let updates: Updates

  private let compute: @Sendable () async throws -> DataValue

  private let storage: CriticalState<Storage>

  public init(
    lazy compute: @escaping @Sendable () async throws -> DataValue
  ) {
    self.storage = .init(
      .init(
        state: .initial,
        sourceUpdates: .once,
        awaiters: .init()
      )
    )
    self.updates = .once
    self.compute = compute
  }

  public init(
    using updates: Updates,
    compute: @escaping @Sendable () async throws -> DataValue
  ) {
    self.storage = .init(
      .init(
        state: .initial,
        sourceUpdates: updates,
        awaiters: .init()
      )
    )
    self.updates = updates
    self.compute = compute
  }

  public init<Source>(
    from source: Source,
    transform: @escaping @Sendable (Source.DataValue) async throws -> DataValue
  ) where Source: DataSource {
    self.storage = .init(
      .init(
        state: .initial,
        sourceUpdates: source.updates,
        awaiters: .init()
      )
    )
    self.updates = source.updates
    self.compute = { @Sendable [weak source] () async throws -> DataValue in
      guard let source else { throw CancellationError() }
      return try await transform(source.current)
    }
  }

  public init<SourceA, SourceB>(
    combining sourceA: SourceA,
    and sourceB: SourceB,
    combine: @escaping @Sendable (SourceA.DataValue, SourceB.DataValue) async throws -> DataValue
  ) where SourceA: DataSource, SourceB: DataSource {
    self.storage = .init(
      .init(
        state: .initial,
        sourceUpdates: .init(
          combined: sourceA.updates,
          with: sourceB.updates
        ),
        awaiters: .init()
      )
    )
    self.updates = .init(
      combined: sourceA.updates,
      with: sourceB.updates
    )
    self.compute = { @Sendable [weak sourceA, weak sourceB] () async throws -> DataValue in
      // this implementation could keep last value cache so it can keep updating
      // if only one of sources is not available
      guard let sourceA, let sourceB else { throw CancellationError() }
      // there is a risk of A or B producing more than one update
      // while the other one does not produce at all
      // ignoring the problem until it becomes an actuall issue
      // since it requires either very frequent changes or significant
      // difference in update duration between both sources to occur
      // final result will be recomputed again anyway after one
      // of the sources produces an update
      async let dataA: SourceA.DataValue = sourceA.current
      async let dataB: SourceB.DataValue = sourceB.current
      return try await combine(dataA, dataB)
    }
  }

  public convenience init<SourceA, SourceB>(
    combining sourceA: SourceA,
    and sourceB: SourceB
  ) where SourceA: DataSource, SourceB: DataSource, DataValue == (SourceA.DataValue, SourceB.DataValue) {
    self.init(
      combining: sourceA,
      and: sourceB,
      combine: { ($0, $1) }
    )
  }

  public var current: DataValue {
    get async throws {
      let iid: IID = .init()
      return try await withTaskCancellationHandler(
        operation: { () async throws -> DataValue in
          try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<DataValue, Error>) in
            self.storage.access { (storage: inout Storage) in
              guard !Task.isCancelled
              else { return continuation.resume(throwing: CancellationError()) }

              switch storage.state {
              case .cached(let value):
                // there is a risk that between checking update
                // and receiving an update new value occurs in source,
                // it will trigger unnecessary recomputation of current
                // value but should not affect correctness of result
                if storage.sourceUpdates.checkUpdate() {
                  storage.runningUpdate?.cancel()
                  storage.awaiters[iid] = continuation
                  storage.runningUpdate = .init { [compute, weak self] in
                    do {
                      let updated: DataValue = try await compute()
                      self?.update(with: updated)
                    }
                    catch is CancellationError where Task.isCancelled {
                      // task is cancelled, it will pass cancellation error
                      // caused by missing source which is correct behavior
                    }
                    catch {
                      self?.terminate(with: error)
                    }
                  }
                }
                else if case .some = storage.runningUpdate {
                  storage.awaiters[iid] = continuation
                }
                else {
                  return continuation.resume(returning: value)
                }

              case .terminal(let error):
                return continuation.resume(throwing: error ?? CancellationError())

              case .initial:
                storage.awaiters[iid] = continuation
                guard case .none = storage.runningUpdate
                else { return }  // already scheduled, just wait
                // there is a risk that between checking update
                // and receiving an update new value occurs in source,
                // it will trigger unnecessary recomputation of current
                // value but should not affect correctness of result
                storage.sourceUpdates.checkUpdate()  // called to update current generation
                storage.runningUpdate = .init { [compute, weak self] in
                  do {
                    let updated: DataValue = try await compute()
                    self?.update(with: updated)
                  }
                  catch is CancellationError where Task.isCancelled {
                    // task is cancelled, it will pass cancellation error
                    // caused by missing source which is correct behavior
                  }
                  catch {
                    self?.terminate(with: error)
                  }
                }
              }
            }
          }
        },
        onCancel: {
          self.storage
            .exchange(\.awaiters[iid], with: .none)?
            .resume(throwing: CancellationError())
        }
      )
    }
  }

  private func update(
    with value: DataValue
  ) {
    guard !Task.isCancelled else { return }
    let deliverUpdate: () -> Void = self.storage.access { (storage: inout Storage) -> () -> Void in
      assert(storage.runningUpdate != nil)
      storage.runningUpdate = .none
      switch storage.state {
      case .cached, .initial:
        storage.state = .cached(value)

        let awaitersToResume: Dictionary<IID, UnsafeContinuation<DataValue, Error>>.Values = storage.awaiters.values
        storage.awaiters = .init()

        return { () -> Void in
          // we could check if there is any new update and schedule
          // it before notifying awaiters to ensure always latest value
          // on the other hand it could lead to starvation
          for continuation: UnsafeContinuation<DataValue, Error> in awaitersToResume {
            continuation.resume(returning: value)
          }
        }

      case .terminal:
        assert(storage.awaiters.isEmpty)
        return {}  // can't update terminated
      }
    }

    deliverUpdate()
  }

  private func terminate(
    with error: Failure?
  ) {
    guard !Task.isCancelled else { return }
    let deliverUpdate: () -> Void = self.storage.access { (storage: inout Storage) -> () -> Void in
      assert(storage.runningUpdate != nil)
      storage.runningUpdate = .none
      switch storage.state {
      case .cached, .initial:
        storage.sourceUpdates.generation = .max
        storage.state = .terminal(error)

        let awaitersToResume: Dictionary<IID, UnsafeContinuation<DataValue, Error>>.Values = storage.awaiters.values
        storage.awaiters.removeAll()

        return { () -> Void in
          // we could check if there is any new update and schedule
          // it before notifying awaiters to ensure always latest value
          // on the other hand it could lead to starvation
          for continuation: UnsafeContinuation<DataValue, Error> in awaitersToResume {
            continuation.resume(throwing: error ?? CancellationError())
          }
        }

      case .terminal:
        assert(storage.awaiters.isEmpty)
        return {}  // can't update terminated
      }
    }

    deliverUpdate()
  }
}
