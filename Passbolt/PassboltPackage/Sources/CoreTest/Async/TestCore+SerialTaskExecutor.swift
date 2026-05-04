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

// based on https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/MainSerialExecutor.swift
@MainActor
public func withSerialTaskExecutor<Returned>(
  @_implicitSelfCapture operation: @MainActor () async throws -> Returned
) async rethrows -> Returned {
  let didUseMainSerialExecutor = uncheckedUseMainSerialExecutor
  defer { uncheckedUseMainSerialExecutor = didUseMainSerialExecutor }
  uncheckedUseMainSerialExecutor = true
  return try await operation()
}

/// Overrides Swift's global executor with the main serial executor in an unchecked fashion.
///
/// > Warning: When set to `true`, all tasks will be enqueued on the main serial executor till set
/// > back to `false`. Consider using ``withMainSerialExecutor(operation:)-7fqt1``, instead, which
/// > scopes this work to the duration of a given operation.
public var uncheckedUseMainSerialExecutor: Bool {
  get { swift_task_enqueueGlobal_hook != nil }
  set {
    swift_task_enqueueGlobal_hook =
      newValue
      ? { job, _ in MainActor.shared.enqueue(job) }
      : nil
  }
}

private typealias Original = @convention(thin) (UnownedJob) -> Void
private typealias Hook = @convention(thin) (UnownedJob, Original) -> Void

// swift-format-ignore: AlwaysUseLowerCamelCase
private var swift_task_enqueueGlobal_hook: Hook? {
  get { _swift_task_enqueueGlobal_hook.wrappedValue.pointee }
  set { _swift_task_enqueueGlobal_hook.wrappedValue.pointee = newValue }
}

// swift-format-ignore: AlwaysUseLowerCamelCase, NoLeadingUnderscores
private let _swift_task_enqueueGlobal_hook = UncheckedSendable(
  dlsym(dlopen(nil, 0), "swift_task_enqueueGlobal_hook").assumingMemoryBound(to: Hook?.self)
)

private struct UncheckedSendable<Value>: @unchecked Sendable {
  /// The unchecked value.
  fileprivate var value: Value

  /// Initializes unchecked sendability around a value.
  ///
  /// - Parameter value: A value to make sendable in an unchecked way.
  fileprivate init(_ value: Value) {
    self.value = value
  }

  fileprivate init(wrappedValue: Value) {
    self.value = wrappedValue
  }

  fileprivate var wrappedValue: Value {
    _read { yield self.value }
    _modify { yield &self.value }
  }

  fileprivate var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}
