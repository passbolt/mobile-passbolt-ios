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

import OSFeatures
import Session

import class Foundation.JSONDecoder

// MARK: - Implementation

extension SessionNetworkRequestExecutor {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let sessionState: SessionState = try features.instance()
    let sessionStateEnsurance: SessionStateEnsurance = try features.instance()
    let sessionAuthorizationState: SessionAuthorizationState = try features.instance()
    let networkRequestExecutor: NetworkRequestExecutor = try features.instance()

    @SessionActor @Sendable func prepareRequest(
      _ mutation: Mutation<HTTPRequest>,
      for account: Account
    ) async throws -> HTTPRequest {
      let accessToken: SessionAccessToken = try await sessionStateEnsurance.accessToken(account)
      let mfaToken: SessionMFAToken? = sessionState.mfaToken()

      return Mutation<HTTPRequest>
        .combined(
          .url(string: account.domain.rawValue),
          .header(
            "Authorization",
            value: "Bearer \(accessToken.rawValue)"
          ),
          .whenSome(
            mfaToken,
            then: { (mfaToken: SessionMFAToken) in
              .header(
                "Cookie",
                value: "passbolt_mfa=\(mfaToken)"
              )
            }
          ),
          mutation
        )
        .instantiate()
    }

    @SessionActor @Sendable func retry(
      _ requestMutation: Mutation<HTTPRequest>,
      for account: Account
    ) async throws -> HTTPResponse {
      try await sessionAuthorizationState
        .waitForAuthorizationIfNeeded(
          .passphrase(account)
        )

      return
        try await networkRequestExecutor
        .execute(
          prepareRequest(
            requestMutation,
            for: account
          )
        )
    }

    @SessionActor @Sendable func execute(
      _ requestMutation: Mutation<HTTPRequest>
    ) async throws -> HTTPResponse {
      guard let account: Account = sessionState.account()
      else { throw SessionMissing.error() }

      do {
        return
          try await networkRequestExecutor
          .execute(
            prepareRequest(
              requestMutation,
              for: account
            )
          )
      }
      catch is HTTPUnauthorized {
        sessionState.accessTokenInvalidate()
        try sessionState
          .authorizationRequested(.passphrase(account))

        return try await retry(
          requestMutation,
          for: account
        )
      }
      catch let forbidden as HTTPForbidden {
        guard let mfaResponse: MFARequiredResponse = decodeMFARequired(from: forbidden.response, using: JSONDecoder.default)
        else { throw forbidden }

        sessionState.mfaTokenInvalidate()
        try sessionState
          .authorizationRequested(
            .mfa(
              account,
              providers: mfaResponse.body.mfaProviders
            )
          )

        return try await retry(
          requestMutation,
          for: account
        )
      }
      catch let redirect as HTTPRedirect {
				// redirect handling exceptpion for DUO
				if redirect.request.url?.path.hasSuffix("/mfa/verify/duo/prompt") ?? false {
					return redirect.response
				} // else continue error handling

        let locationURLString: URLString = redirect.location.urlString

        guard locationURLString.rawValue.hasSuffix("/mfa/verify/error.json")
        else { throw redirect }

        guard
          URLString.domain(
            forURL: locationURLString,
            matches: account.domain
          )
        else { throw redirect }

        do {
          let redirectResponse: HTTPResponse =
            try await networkRequestExecutor
            .execute(
              prepareRequest(
                .combined(
                  .url(redirect.location),
                  .method(.get)
                ),
                for: account
              )
            )

          guard let mfaResponse: MFARequiredResponse = decodeMFARequired(from: redirectResponse, using: JSONDecoder.default)
          else { throw redirect }

          sessionState.mfaTokenInvalidate()
          try sessionState
            .authorizationRequested(
              .mfa(
                account,
                providers: mfaResponse.body.mfaProviders
              )
            )

          return try await retry(
            requestMutation,
            for: account
          )
        }
        catch _ as HTTPUnauthorized {
          sessionState.accessTokenInvalidate()
          try sessionState
            .authorizationRequested(.passphrase(account))

          return try await retry(
            requestMutation,
            for: account
          )
        }
        catch let forbidden as HTTPForbidden {
          guard let mfaResponse: MFARequiredResponse = decodeMFARequired(from: forbidden.response, using: JSONDecoder.default)
          else { throw forbidden }

          sessionState.mfaTokenInvalidate()
          try sessionState
            .authorizationRequested(
              .mfa(
                account,
                providers: mfaResponse.body.mfaProviders
              )
            )

          return try await retry(
            requestMutation,
            for: account
          )
        }
        catch {
          throw error
        }
      }
      catch {
        throw error
      }
    }

    return Self(
      execute: execute(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionNetworkRequestExecutor() {
    self.use(
      .lazyLoaded(
        SessionNetworkRequestExecutor.self,
        load: SessionNetworkRequestExecutor
          .load(features:cancellables:)
      )
    )
  }
}

private struct MFARequiredResponse: Decodable {

  fileprivate struct Body: Decodable {

    fileprivate var mfaProviders: Array<SessionMFAProvider>

    fileprivate enum CodingKeys: String, CodingKey {

      case mfaProviders = "mfa_providers"
    }
  }

  fileprivate var body: Body
}

@Sendable nonisolated private func decodeMFARequired(
  from response: HTTPResponse,
  using decoder: JSONDecoder
) -> MFARequiredResponse? {
  guard response.statusCode == 403
  else { return .none }

  return
    try? decoder
    .decode(
      MFARequiredResponse.self,
      from: response.body
    )
}
