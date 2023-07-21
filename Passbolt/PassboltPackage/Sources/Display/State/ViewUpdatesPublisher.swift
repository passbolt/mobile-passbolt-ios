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

internal final class ViewUpdatesPublisher<ViewState>: ConnectablePublisher
where ViewState: Equatable {

  public typealias Output = ViewState
  public typealias Failure = Never

  internal var connection: @Sendable () async -> Void
  private let subject: PassthroughSubject<ViewState, Failure>

  internal init(
    initial: ViewState,
    connection: @escaping @Sendable () async -> Void = {}
  ) {
    self.subject = .init()
    self.connection = connection
  }

  @MainActor internal func send(
    _ state: ViewState
  ) {
    assert(
      Thread.isMainThread,
      "It seems that @MainActor does not work properly in some scenatios... yet this have to be on main!"
    )
    self.subject.send(state)
  }

  internal func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Output, S.Failure == Failure {
    self.subject
      .receive(subscriber: subscriber)
  }

  internal func connect() -> Cancellable {
    let task: Task<Void, Never> = .init(
      priority: .userInitiated,
      operation: self.connection
    )
    return AnyCancellable(task.cancel)
  }
}
