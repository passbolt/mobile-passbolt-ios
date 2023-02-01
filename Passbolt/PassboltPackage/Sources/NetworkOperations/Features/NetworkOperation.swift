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

// MARK: - Interface

/// Network based operation.
public struct NetworkOperation<Description>
where Description: NetworkOperationDescription {

  public typealias Input = Description.Input
  public typealias Output = Description.Output

  /// Execute operation optionally using current session.
  /// Throws if there is no session and session was required.
  public var execute: @Sendable (Input) async throws -> Output

  public init(
    execute: @escaping @Sendable (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension NetworkOperation: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      execute: unimplemented()
    )
  }
  #endif
}

extension NetworkOperation {

  public func callAsFunction(
    _ input: Input
  ) async throws -> Output {
    try await self.execute(input)
  }
}

extension NetworkOperation
where Input == Void {

  public func callAsFunction() async throws -> Output {
    try await self.execute(Void())
  }
}
