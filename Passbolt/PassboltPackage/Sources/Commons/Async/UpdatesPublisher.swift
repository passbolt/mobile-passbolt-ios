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

public final class UpdatesPublisher: ConnectablePublisher {

  public typealias Output = Void
  public typealias Failure = Never

  private let subject: CurrentValueSubject<Void, Failure> = .init(Void())
  private let iteratorNext: () async -> Void?

  @usableFromInline internal init(
    for updates: Updates
  ) {
    var local: Updates = updates
    self.iteratorNext = { await local.next() }
  }

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, S.Input == Output, S.Failure == Failure {
    self.subject
      .receive(subscriber: subscriber)
  }

  public func connect() -> Cancellable {
    let task: Task<Void, Never> = .init {
      while case .some = await self.iteratorNext() {
        self.subject.send(Void())
      }
      self.subject.send(completion: .finished)
    }

    return AnyCancellable(task.cancel)
  }
}
