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
import Commons
import Environment

public struct NetworkRequest<SessionVariable, Variable, Response> {

  public var execute: (Variable) -> AnyPublisher<Response, TheErrorLegacy>
}

extension NetworkRequest {

  internal init(
    template: NetworkRequestTemplate<SessionVariable, Variable>,
    responseDecoder: NetworkResponseDecoding<SessionVariable, Variable, Response>,
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<SessionVariable, TheErrorLegacy>
  ) {
    self.execute = { requestVariable in
      sessionVariablePublisher
        .first()
        .map { sessionVariable -> (SessionVariable, HTTPRequest) in
          (
            sessionVariable,
            template
              .prepareRequest(
                with: sessionVariable,
                and: requestVariable
              )
          )
        }
        .map { sessionVariable, request -> AnyPublisher<Response, TheErrorLegacy> in
          networking
            .make(request, useCache: template.cacheResponse)
            .mapError { error -> TheErrorLegacy in
              switch error {
              case let .cannotConnect(url), let .timeout(url):
                return TheErrorLegacy.serverNotReachable(url: url, underlyingError: error)
              case .invalidRequest, .invalidResponse, .other:
                return TheErrorLegacy.httpError(error)
              case .canceled:
                return TheErrorLegacy.canceled
              }
            }
            .map(withResultAsPublisher({ responseDecoder.decode(sessionVariable, requestVariable, $0) }))
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
  }
}

extension NetworkRequest {

  public func make(
    using variable: Variable
  ) -> AnyPublisher<Response, TheErrorLegacy> {
    execute(variable)
  }
}

extension NetworkRequest where Variable == Void {

  public func make() -> AnyPublisher<Response, TheErrorLegacy> {
    execute(Void())
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
    _ publisher: AnyPublisher<Response, TheErrorLegacy>,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return publisher
      }
    )
  }

  public static func respondingWith(
    _ response: Response,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return Just(response)
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
    )
  }

  public static func failingWith(
    _ error: TheErrorLegacy,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return Fail<Response, TheErrorLegacy>(error: error)
          .eraseToAnyPublisher()
      }
    )
  }
}
#endif
