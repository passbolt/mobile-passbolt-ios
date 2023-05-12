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

import Commons

public struct AsyncExecutor {

  public let cancelTasks: @Sendable () -> Void
  private let execute:
    @Sendable (ExecutionIdentifier, OngoingExecutionBehavior, @escaping @Sendable () async -> Void) -> Execution
}

extension AsyncExecutor: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: AsyncExecutor {
    .init(
      cancelTasks: unimplemented0(),
      execute: unimplemented3()
    )
  }
  #endif
}

extension AsyncExecutor {

  @discardableResult
  public func schedule(
    _ behavior: OngoingExecutionBehavior = .unmanaged,
    identifier: ExecutionIdentifier,
    _ task: @escaping @Sendable () async -> Void
  ) -> Execution {
    self.execute(identifier, behavior, task)
  }

  @discardableResult
  public func schedule(
    _ behavior: OngoingExecutionBehavior = .concurrent,
    function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    _ task: @escaping @Sendable () async -> Void
  ) -> Execution {
    self.execute(
      .contextual(
        function: function,
        file: file,
        line: line
      ),
      behavior,
      task
    )
  }

  @_transparent
  public func scheduleIteration<S>(
    over sequence: S,
    catchingWith diagnostics: OSDiagnostics,
    failMessage: StaticString? = .none,
    behavior: OngoingExecutionBehavior = .concurrent,
    function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    _ handleNext: @escaping @Sendable (S.Element) async throws -> Void
  ) where S: AsyncSequence {
    self.scheduleRecursiveNext(
      using: sequence.makeAsyncIterator().asAnyAsyncThrowingIterator(),
      catchingWith: diagnostics,
      failMessage: failMessage,
      behavior: behavior,
      function: function,
      file: file,
      line: line,
      handleNext
    )
  }

  @usableFromInline
  internal func scheduleRecursiveNext<Element>(
    using iterator: AnyAsyncThrowingIterator<Element>,
    catchingWith diagnostics: OSDiagnostics,
    failMessage: StaticString?,
    behavior: OngoingExecutionBehavior,
    function: StaticString,
    file: StaticString,
    line: UInt,
    _ handleNext: @escaping @Sendable (Element) async throws -> Void
  ) {
    self.schedule(
      behavior,
      function: function,
      file: file,
      line: line,
      {
        await diagnostics
          .withLogCatch(
            info:
              failMessage
              .map { (message: StaticString) -> DiagnosticsInfo in
                .message(
                  message,
                  file: file,
                  line: line
                )
              }
          ) {
            guard let nextElement: Element = try await iterator.next()
            else { return }
            try await handleNext(nextElement)
            // if it not failed schedule recursively for next
            self.scheduleRecursiveNext(
              using: iterator,
              catchingWith: diagnostics,
              failMessage: failMessage,
              behavior: behavior,
              function: function,
              file: file,
              line: line,
              handleNext
            )
          }
      }
    )
  }

  @discardableResult @_transparent
  public func scheduleCatchingWith(
    _ diagnostics: OSDiagnostics,
    failMessage: StaticString? = .none,
    behavior: OngoingExecutionBehavior = .concurrent,
    function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    _ task: @escaping @Sendable () async throws -> Void
  ) -> Execution {
    self.schedule(
      behavior,
      function: function,
      file: file,
      line: line,
      {
        await diagnostics
          .withLogCatch(
            info:
              failMessage
              .map { (message: StaticString) -> DiagnosticsInfo in
                .message(
                  message,
                  file: file,
                  line: line
                )
              }
          ) {
            try await task()
          }
      }
    )
  }

  @discardableResult @_transparent
  public func scheduleCatching(
    with diagnostics: OSDiagnostics,
    failMessage: StaticString? = .none,
    behavior: OngoingExecutionBehavior = .concurrent,
    identifier: ExecutionIdentifier,
    function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    _ task: @escaping @Sendable () async throws -> Void
  ) -> Execution {
    self.schedule(
      behavior,
      function: function,
      file: file,
      line: line,
      {
        await diagnostics
          .withLogCatch(
            info:
              failMessage
              .map { (message: StaticString) -> DiagnosticsInfo in
                .message(
                  message,
                  file: file,
                  line: line
                )
              }
          ) {
            try await task()
          }
      }
    )
  }
}

extension AsyncExecutor {

  public static func system() -> Self {
    .executor { (task: @escaping @Sendable () async -> Void) in
      let task: Task<Void, Never> = .init(operation: task)
      return .init(
        isCancelled: { task.isCancelled },
        cancellation: { task.cancel() },
        waitForCompletion: { await task.value }
      )
    }
  }

  #if DEBUG
  public static func mock(
    _ mockControl: MockExecutionControl
  ) -> Self {
    .executor(mockControl.addTask(_:))
  }
  #endif

  private static func executor(
    _ executeTask: @escaping @Sendable (@escaping @Sendable () async -> Void) -> Execution
  ) -> Self {
    let schedulerState: CriticalState<Dictionary<ExecutionIdentifier, Execution>> = .init(
      .init(),
      cleanup: { state in
        state.values.forEach { item in
          item.cancel()
        }
      }
    )

    @Sendable func execute(
      _ identifier: ExecutionIdentifier,
      behavior: OngoingExecutionBehavior,
      task: @escaping @Sendable () async -> Void
    ) -> Execution {
      let execution: Execution

      switch behavior {
      case .replace:
        execution = schedulerState.access { state in
          // cancel current queue if any
          state[identifier]?.cancel()

          let currentExecution: Execution =
            executeTask { [weak schedulerState] in
              guard !Task.isCancelled else { return }
              await task()
              guard !Task.isCancelled else { return }
              schedulerState?.set(\.[identifier], .none)
            }
          state[identifier] = currentExecution
          return currentExecution
        }

      case .reuse:
        execution = schedulerState.access { state in
          if let currentExecution: Execution = state[identifier], !currentExecution.isCancelled() {
            // reuse current
            return currentExecution
          }
          else {
            let currentExecution: Execution =
              executeTask { [weak schedulerState] in
                guard !Task.isCancelled else { return }
                await task()
                guard !Task.isCancelled else { return }
                schedulerState?.set(\.[identifier], .none)
              }
            state[identifier] = currentExecution
            return currentExecution
          }
        }

      case .unmanaged:
        execution = executeTask(task)

      case .concurrent:
        execution = schedulerState.access { state in
          let execution: Execution = executeTask(task)
          state[.unique()] = execution
          return execution
        }
      }

      return execution
    }

    return .init(
      cancelTasks: {
        schedulerState.access { state in
          state.values.forEach { item in
            item.cancel()
          }
        }
      },
      execute: execute(_:behavior:task:)
    )
  }
}

extension AsyncExecutor {

  public enum OngoingExecutionBehavior {

    case unmanaged  // execute task concurrently without tracking
    case replace  // cancel and replace current and pending taskscase concurrent // execute task concurrently
    case reuse  // reuse current task instead (ignore queue)
    case concurrent  // execute task concurrently

    // case enqueue // push a task on queue to be executed
  }

  public struct ExecutionIdentifier: Hashable {

    private let identifier: AnyHashable

    public static func contextual(
      function: StaticString,
      file: StaticString,
      line: UInt
    ) -> Self {
      .init(
        identifier: "\(file):\(function):\(line)"
      )
    }

    public static func unique() -> Self {
      .init(
        identifier: IID()
      )
    }
  }

  public struct Execution: Sendable {

    fileprivate let isCancelled: @Sendable () -> Bool
    fileprivate let cancellation: @Sendable () -> Void
    fileprivate let waitForCompletion: @Sendable () async -> Void

    @Sendable public func cancel() {
      self.cancellation()
    }

    @Sendable public func waitForCompletion() async {
      await self.waitForCompletion()
    }
  }
}

extension AsyncExecutor.ExecutionIdentifier: ExpressibleByStringInterpolation {

  public typealias StringLiteralType = String

  public init(
    stringLiteral value: String
  ) {
    self.identifier = value
  }
}

#if DEBUG
extension AsyncExecutor {

  public func updates(
    using sequence: UpdatesSequence,
    update: @escaping @Sendable () async throws -> Void,
    finish: @escaping @Sendable (TheError?) -> Void = { _ in /* NOP */ }
  ) {
    self.schedule {
      do {
        for try await _ in sequence {
          try await update()
        }
        finish(.none)
      }
      catch {
        finish(error.asTheError())
      }
    }
  }

  public struct MockExecutionControl: Sendable {

    private struct QueueItem {

      @IID fileprivate var id
      fileprivate let execute: @Sendable () async -> Void
      fileprivate let completion: AsyncVariable<Void?>
    }

    private let executionQueue: CriticalState<Array<QueueItem>> = .init(
      .init(),
      cleanup: { state in
        precondition(
          state.isEmpty,
          "Unexecuted tasks cannot be removed..."
        )
      }
    )

    public init() {}

    public var scheduledTasksCount: Int {
      executionQueue.get(\.count)
    }

    @Sendable public func executeNext() async {
      if let next: @Sendable () async -> Void = self.nextTask() {
        await next()
      }  // else NOP
    }

    @Sendable public func execute<Returned>(
      _ task: () async throws -> Returned
    ) async throws -> Returned {
      precondition(self.executionQueue.access(\.isEmpty))
      async let returned: Returned = task()
      async let result: Void = Task {
        while !Task.isCancelled {
          switch self.nextTask() {
          case .none:
            await Task.yield()

          case let .some(task):
            return await task()
          }
        }
      }
      .value
      return try await (returned, result).0
    }

    @Sendable public func executeAll() async {
      await withTaskGroup(of: Void.self) { group in
        while let next: @Sendable () async -> Void = self.nextTask() {
          group.addTask {
            await next()
          }
        }
        await group.waitForAll()
      }
    }

    @discardableResult
    @Sendable public func addTask(
      _ task: @escaping @Sendable () async -> Void
    ) -> Execution {
      let completion: AsyncVariable<Void?> = .init(initial: .none)
      let queueItem: QueueItem = .init(
        execute: {
          await task()
          completion.send(Void())
        },
        completion: completion
      )
      self.executionQueue.access { state in
        state.append(queueItem)
      }

      return .init(
        isCancelled: {
          self.executionQueue.access { state in
            !state.contains(where: { $0.id == queueItem.id })
          }
        },
        cancellation: {
          self.executionQueue.access { state in
            state.removeAll(where: { $0.id == queueItem.id })
            completion.send(Void())
          }
        },
        waitForCompletion: {
          await completion
            .compactMap(identity)
            .first()
        }
      )
    }

    @Sendable private func nextTask() -> (@Sendable () async -> Void)? {
      self.executionQueue.access { state in
        if state.isEmpty {
          return .none
        }
        else {
          return state.removeFirst().execute
        }
      }
    }
  }
}
#endif

extension FeaturesRegistry {

  public mutating func usePassboltAsyncExecutor() {
    self.use(
      .disposable(
        AsyncExecutor.self,
        load: { (_: Features) in
          AsyncExecutor.system()
        }
      )
    )
  }
}
