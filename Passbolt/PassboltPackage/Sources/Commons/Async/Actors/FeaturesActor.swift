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

// Actor used to synchronize access to features
// container and feature instances. All operations
// related to accessing, loading and unloading
// feature instances should be performed with this actor.
// ``FeaturesFactory`` is the main user of this actor
// but each feature ``load``method has to be also executed on that actor.
@globalActor
public final actor FeaturesActor {

  public static var shared: FeaturesActor = .init()

  public static func execute<Success>(
    _ operation: @escaping @FeaturesActor () async throws -> Success
  ) async throws -> Success {
    try await Task { @FeaturesActor in
      try await operation()
    }
    .value
  }

  public static func execute(
    _ operation: @FeaturesActor @escaping () async throws -> Void
  ) {
    Task { @FeaturesActor in
      try await operation()
    }
  }

  public static func executeDetached(
    _ operation: @FeaturesActor @escaping () async throws -> Void
  ) {
    Task.detached { @FeaturesActor in
      try await operation()
    }
  }

  public static func executeWithPublisher<Success>(
    _ operation: @escaping @FeaturesActor () async throws -> Success
  ) -> AnyPublisher<Success, Error> {
    Task { @FeaturesActor in
      try await operation()
    }
    .asPublisher()
  }

  public static func executeWithPublisher<Success>(
    _ operation: @FeaturesActor @escaping () async throws -> Success
  ) -> AnyPublisher<Success.Output, Error>
  where Success: Publisher {
    Task { @FeaturesActor in
      try await operation()
        .eraseErrorType()
    }
    .asPublisher()
    .switchToLatest()
    .eraseToAnyPublisher()
  }
}
