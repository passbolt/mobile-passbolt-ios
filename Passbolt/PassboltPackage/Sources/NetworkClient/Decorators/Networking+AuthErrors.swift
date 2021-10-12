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

import Commons
import Environment

extension NetworkRequest {

  internal func withAuthErrors(
    authorizationRequest: @escaping () -> Void,
    mfaRequest: @escaping (Array<MFAProvider>) -> Void,
    mfaRedirectionHandler: @escaping (MFARedirectRequestVariable) -> AnyPublisher<MFARedirectResponse, TheError>,
    sessionPublisher: AnyPublisher<DomainSessionVariable, TheError>
  ) -> Self {
    Self(
      execute: { variable in
        self.execute(variable)
          .catch { error -> AnyPublisher<Response, TheError> in
            if error.identifier == .redirect,
               let location = error.redirectLocation.map(URLString.init(rawValue:)) {

              return sessionPublisher
                .map { URLString(rawValue: $0.domain) }
                .map { domain -> AnyPublisher<Response, TheError> in
                  if URLString.domain(forURL: location, matches: domain),
                     location.hasSuffix("/mfa/verify/error.json") {
                    return mfaRedirectionHandler(.init())
                      .map { _ -> AnyPublisher<Response, TheError> in
                        Fail(error: .internalInconsistency().appending(context: "MFA Redirect response invalid"))
                          .eraseToAnyPublisher()
                      }
                      .switchToLatest()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: error)
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .eraseToAnyPublisher()
            }
            else {
              return Fail(error: error)
                .eraseToAnyPublisher()
            }
          }
          .mapError { (error: TheError) -> TheError in
            if error.identifier == .missingSession {
              authorizationRequest()
            }
            else if error.identifier == .mfaRequired {
              mfaRequest(error.mfaProviders)
            }
            else {
              /* NOP */
            }

            return error
          }
          .eraseToAnyPublisher()
      }
    )
  }
}
