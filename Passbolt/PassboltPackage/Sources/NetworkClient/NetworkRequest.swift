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
  
  public var execute: (Variable) -> AnyPublisher<Response, TheError>
}

extension NetworkRequest {
  
  internal init(
    template: NetworkRequestTemplate<SessionVariable, Variable>,
    responseDecoder: NetworkResponseDecoding<Response>,
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<SessionVariable, TheError>
  ) {
    self.execute = { requestVariable in
      sessionVariablePublisher
        .first()
        .map { sessionVariable -> HTTPRequest in
          template
            .prepareRequest(
              with: sessionVariable,
              and: requestVariable
            )
        }
        .map { request -> AnyPublisher<Response, TheError> in
          networking
            .make(request, useCache: template.cacheResponse)
            .mapError(TheError.httpError)
            .map(withResultAsPublisher(responseDecoder.decode))
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
  ) -> AnyPublisher<Response, TheError> {
    execute(variable)
  }
}

#if DEBUG
extension NetworkRequest {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      execute: Commons.placeholder("You have to provide mocks for used methods")
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
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
      }
    )
  }
  
  public static func failingWith(
    _ error: TheError,
    storeVariableIn requestVariableReference: UnsafeMutablePointer<Variable?>? = nil
  ) -> Self {
    Self(
      execute: { variable in
        requestVariableReference?.pointee = variable
        return Fail<Response, TheError>(error: error)
          .eraseToAnyPublisher()
      }
    )
  }
}
#endif
