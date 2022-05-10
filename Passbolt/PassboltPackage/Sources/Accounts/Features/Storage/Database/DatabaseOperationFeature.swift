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

import Features

public protocol DatabaseOperationFeature: Feature {

  associatedtype Input
  associatedtype Output

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self

  init(execute: @escaping @StorageAccessActor (Input) async throws -> Output)

  var execute: @StorageAccessActor (Input) async throws -> Output { get }
}

extension DatabaseOperationFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let database: AccountDatabase = try await features.instance()

    return Self.using(
      database.currentConnection
    )
  }

  public nonisolated var featureUnload: @FeaturesActor () async throws -> Void { { /* NOP */ } }

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      execute: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension DatabaseOperationFeature {

  @StorageAccessActor public func callAsFunction(
    _ input: Input
  ) async throws -> Output {
    try await self.execute(input)
  }
}

extension DatabaseOperationFeature
where Input == Void {

  @StorageAccessActor public func callAsFunction() async throws -> Output {
    try await self.execute(Void())
  }
}

extension DatabaseOperationFeature {

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
