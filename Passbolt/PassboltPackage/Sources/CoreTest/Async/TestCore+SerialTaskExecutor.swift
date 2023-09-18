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

import Foundation

// based on https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/MainSerialExecutor.swift

extension TestCase {

  @MainActor public final func withSerialTaskExecutor<Returned>(
    @_implicitSelfCapture operation: @MainActor @Sendable () async throws -> Returned
  ) async rethrows -> Returned {
    swift_task_enqueueGlobal_hook = mainSerialExecutor
    defer { swift_task_enqueueGlobal_hook = .none }
    return try await operation()
  }

  public nonisolated final func withSerialTaskExecutor<Returned>(
    @_implicitSelfCapture operation: () throws -> Returned
  ) rethrows -> Returned {
    swift_task_enqueueGlobal_hook = mainSerialExecutor
    defer { swift_task_enqueueGlobal_hook = .none }
    return try operation()
  }
}

private typealias TaskEnqueueHook = @convention(thin) (UnownedJob, @convention(thin) (UnownedJob) -> Void) -> Void

private var swift_task_enqueueGlobal_hook: TaskEnqueueHook? {
  get { swift_task_enqueueGlobal_hook_ptr.pointee }
  set { swift_task_enqueueGlobal_hook_ptr.pointee = newValue }
}
private let swift_task_enqueueGlobal_hook_ptr: UnsafeMutablePointer<TaskEnqueueHook?> =
  dlsym(
    dlopen(nil, 0),
    "swift_task_enqueueGlobal_hook"
  )
  .assumingMemoryBound(to: TaskEnqueueHook?.self)

private func mainSerialExecutor(
  job: UnownedJob,
  _: @convention(thin) (UnownedJob) -> Void
) {
  MainActor.shared.enqueue(job)
}
