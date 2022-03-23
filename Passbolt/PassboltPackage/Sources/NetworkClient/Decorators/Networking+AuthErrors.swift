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

import CommonModels
import Environment

extension NetworkRequest {

  internal func withAuthErrors(
    invalidateAccessToken: @AccountSessionActor @escaping () async throws -> Void,
    authorizationRequest: @AccountSessionActor @escaping () async throws -> Void,
    mfaRequest: @escaping @AccountSessionActor (Array<MFAProvider>) async throws -> Void,
    mfaRedirectionHandler: @escaping (MFARedirectRequestVariable) async throws -> MFARedirectResponse,
    sessionVariable: @AccountSessionActor @escaping () async throws -> DomainNetworkSessionVariable
  ) -> Self {
    Self(
      execute: { variable in
        do {
          do {
            return try await self.execute(variable)
          }
          catch let redirect as HTTPRedirect {
            let locationURLString: URLString = redirect.location.urlString
            let currentSessionVariable = try await sessionVariable()

            if URLString.domain(forURL: locationURLString, matches: currentSessionVariable.domain),
              locationURLString.rawValue.hasSuffix("/mfa/verify/error.json")
            {
              let response = try await mfaRedirectionHandler(.init())
              // expecting to get SessionMFAAuthorizationRequired error
              throw
                InternalInconsistency
                .error("Invalid MFA Redirect response")
                .recording(redirect, for: "redirect")
                .recording(response, for: "response")
            }
            else {
              throw redirect
            }
          }
          catch {
            throw error
          }
        }
        catch let error as SessionMissing {
          try await invalidateAccessToken()
          try await authorizationRequest()
          throw error
        }
        catch let error as SessionAuthorizationRequired {
          try await invalidateAccessToken()
          try await authorizationRequest()
          throw error
        }
        catch let mfaRequired as SessionMFAAuthorizationRequired {
          try await mfaRequest(mfaRequired.mfaProviders)
          throw mfaRequired
        }
        catch {
          throw error
        }
      }
    )
  }
}
