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

// Actor used to synchronize storage operations
// including database, user defaults and keychain.
// Those systems can be used as thread safe on its own
// but actor use used to enqueue operations on storage
// to allow more high level synchronization.
@globalActor
public final actor StorageAccessActor {

  public static var shared: StorageAccessActor = .init()

  public static func execute<Success>(
    _ operation: @StorageAccessActor @escaping () async throws -> Success
  ) async throws -> Success {
    try await Task { @StorageAccessActor in
      try await operation()
    }
    .value
  }

  public static func execute(
    _ operation: @StorageAccessActor @escaping () async throws -> Void
  ) {
    Task { @StorageAccessActor in
      try await operation()
    }
  }

  public static func executeDetached(
    _ operation: @StorageAccessActor @escaping () async throws -> Void
  ) {
    Task.detached { @StorageAccessActor in
      try await operation()
    }
  }

  public static func executeWithPublisher<Success>(
    _ operation: @StorageAccessActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    Task { @StorageAccessActor in
      try await operation()
    }
    .asPublisher()
  }

  public static func executeWithPublisher<Success>(
    _ operation: @StorageAccessActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    Task { @StorageAccessActor in
      try await operation()
        .eraseErrorType()
    }
    .asPublisher()
    .switchToLatest()
    .eraseToAnyPublisher()
  }
}
