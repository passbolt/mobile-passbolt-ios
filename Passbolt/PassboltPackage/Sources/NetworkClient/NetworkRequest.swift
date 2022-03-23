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

import Aegithalos
import CommonModels
import Environment

public struct NetworkRequest<SessionVariable, Variable, Response> {

  public var execute: (Variable) async throws -> Response
}

extension NetworkRequest {

  internal init(
    template: NetworkRequestTemplate<SessionVariable, Variable>,
    responseDecoder: NetworkResponseDecoding<SessionVariable, Variable, Response>,
    using networking: Networking,
    with sessionVariable: @AccountSessionActor @escaping () async throws -> SessionVariable
  ) {
    self.execute = { requestVariable in
      let currentSessionVariable: SessionVariable = try await sessionVariable()
      let request: HTTPRequest =
        template
        .prepareRequest(
          with: currentSessionVariable,
          and: requestVariable
        )

      return
        try await responseDecoder
        .decode(
          currentSessionVariable,
          requestVariable,
          request,
          networking.make(request)
        )
    }
  }
}

extension NetworkRequest {

  public func make(
    using variable: Variable
  ) -> AnyPublisher<Response, Error> {
    Task<Response, Error> {
      try await self.execute(variable)
    }
    .asPublisher()
  }

  public func makeAsync(
    using variable: Variable
  ) async throws -> Response {
    try await self.execute(variable)
  }
}

extension NetworkRequest where Variable == Void {

  public func make() -> AnyPublisher<Response, Error> {
    self.make(using: Void())
  }

  public func makeAsync() async throws -> Response {
    try await self.makeAsync(using: Void())
  }
}

#if DEBUG
extension NetworkRequest {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      execute: unimplemented("You have to provide mocks for used methods")
    )
  }

  public static func respondingWith(
    _ result: @escaping @autoclosure () -> Result<Response, Error>,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return try result().get()
      }
    )
  }

  public static func respondingWith(
    _ response: @escaping @autoclosure () -> Response,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return response()
      }
    )
  }

  public static func failingWith(
    _ error: @escaping @autoclosure () -> TheError,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        throw error()
      }
    )
  }
}
#endif
