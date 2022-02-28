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

import Combine

import class Foundation.NSLock

public final class Cancellables {

  fileprivate let lock: NSLock = .init()
  fileprivate var cancellables: Array<AnyCancellable>
  fileprivate var tasks: Array<Task<Void, Never>>

  public init() {
    self.cancellables = .init()
    self.tasks = .init()
  }

  deinit {
    for task in self.tasks {
      task.cancel()
    }
  }

  @discardableResult
  public func take(_ other: Cancellables) -> Self {
    self.cancellables.append(contentsOf: other.cancellables)
    self.tasks.append(contentsOf: other.tasks)
    other.cancellables = .init()
    other.tasks = .init()
    return self
  }

  public func store(_ cancellable: AnyCancellable) {
    self.lock.lock()
    self.cancellables.append(cancellable)
    self.lock.unlock()
  }

  public func task(_ operation: @Sendable @escaping () async -> Void) {
    self.lock.lock()
    self.tasks.append(Task<Void, Never>(operation: operation))
    self.lock.unlock()
  }

  public func store(_ task: Task<Void, Never>) {
    self.lock.lock()
    self.tasks.append(task)
    self.lock.unlock()
  }

  public func clear() {
    self.lock.lock()
    self.cancellables = .init()
    for task in self.tasks {
      task.cancel()
    }
    self.tasks = .init()
    self.lock.unlock()
  }
}

extension AnyCancellable {

  public func store(in cancellables: Cancellables) {
    cancellables.store(self)
  }
}

extension Task where Success == Void, Failure == Never {

  public func store(in cancellables: Cancellables) {
    cancellables.store(self)
  }
}
