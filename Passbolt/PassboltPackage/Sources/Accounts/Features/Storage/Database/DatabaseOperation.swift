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
import CommonModels
import Environment

public struct DatabaseOperation<Input, Output> {

  public var execute: @StorageAccessActor (Input) async throws -> Output
}

extension DatabaseOperation {

  public nonisolated func callAsFunction(
    _ input: Input
  ) -> AnyPublisher<Output, Error> {
    return Task<Output, Error> {
      try await execute(input)
    }
    .asPublisher()
  }

  @StorageAccessActor public func callAsFunction(
    _ input: Input
  ) async throws -> Output {
    try await execute(input)
  }
}

extension DatabaseOperation where Input == Void {

  public nonisolated func callAsFunction() -> AnyPublisher<Output, Error> {
    self.callAsFunction(Void())
  }

  @StorageAccessActor public func callAsFunction() async throws -> Output {
    try await self.callAsFunction(Void())
  }
}

extension DatabaseOperation {

  internal static func withConnection(
    using connection: @escaping () async throws -> SQLiteConnection,
    execute operation: @StorageAccessActor @escaping (SQLiteConnection, Input) throws -> Output
  ) -> Self {
    Self { @StorageAccessActor (input: Input) async throws -> Output in
      let currentConnection = try await connection()
      return try operation(currentConnection, input)
    }
  }

  internal static func withConnectionInTransaction(
    using connection: @escaping () async throws -> SQLiteConnection,
    execute operation: @StorageAccessActor @escaping (SQLiteConnection, Input) throws -> Output
  ) -> Self {
    Self { @StorageAccessActor (input: Input) async throws -> Output in
      let currentConnection = try await connection()
      return try currentConnection.withTransaction { @StorageAccessActor conn in
        return try operation(conn, input)
      }
    }
  }
}

#if DEBUG
extension DatabaseOperation {

  internal static var placeholder: Self {
    Self(
      execute: unimplemented("You have to provide mocks for used methods")
    )
  }

  public static func returning(
    _ result: @autoclosure @escaping () -> Result<Output, Error>,
    storeInputIn inputReference: UnsafeMutablePointer<Input?>? = nil
  ) -> Self {
    Self(
      execute: { input in
        inputReference?.pointee = input
        return try result().get()
      }
    )
  }

  public static func returning(
    _ output: @autoclosure @escaping () -> Output,
    storeInputIn inputReference: UnsafeMutablePointer<Input?>? = nil
  ) -> Self {
    Self(
      execute: { input in
        inputReference?.pointee = input
        return output()
      }
    )
  }

  public static func failingWith(
    _ error: @autoclosure @escaping () -> TheError,
    storeInputIn inputReference: UnsafeMutablePointer<Input?>? = nil
  ) -> Self {
    Self(
      execute: { input in
        inputReference?.pointee = input
        throw error()
      }
    )
  }
}
#endif
