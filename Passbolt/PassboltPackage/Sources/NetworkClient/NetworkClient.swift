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
import Features

public struct NetworkClient {

  public var accountTransferUpdate: AccountTransferUpdateRequest
  // intended to be used for images download and relatively small blobs (few MB)
  public var mediaDownload: MediaDownloadRequest
  public var serverPGPPublicKeyRequest: ServerPGPPublicKeyRequest
  public var serverPublicKeyRequest: ServerJWKSRequest
  public var serverRSAPublicKeyRequest: ServerRSAPublicKeyRequest
  public var signInRequest: SignInRequest
  public var signOutRequest: SignOutRequest
  public var refreshSessionRequest: RefreshSessionRequest
  public var configRequest: ConfigRequest
  public var resourcesRequest: ResourcesRequest
  public var resourcesTypesRequest: ResourcesTypesRequest
  public var resourceSecretRequest: ResourceSecretRequest
  public var totpAuthorizationRequest: TOTPAuthorizationRequest
  public var yubikeyAuthorizationRequest: YubikeyAuthorizationRequest
  public var updateSession: (NetworkSessionVariable?) -> Void
  public var setTokensPublisher: (AnyPublisher<Tokens?, Never>) -> Void
  public var setAuthorizationRequest: (@escaping () -> Void) -> Void
  public var setMFARequest: (@escaping (Array<MFAProvider>) -> Void) -> Void
}

extension NetworkClient {

  public typealias Tokens = (
    accessToken: String,
    isExpired: () -> Bool,
    refreshToken: String
  )
}

extension NetworkClient: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let networking: Networking = environment.networking

    let sessionSubject: CurrentValueSubject<NetworkSessionVariable?, Never> = .init(nil)
    let tokensSubject: CurrentValueSubject<AnyPublisher<Tokens?, Never>, Never> = .init(Empty().eraseToAnyPublisher())

    // accessed without lock - always set during loading initial features, before use
    var authorizationRequest: (() -> Void) = unreachable("Authorization request has to be assigned before use.")
    // accessed without lock - always set during loading initial features, before use
    var mfaRequest: ((Array<MFAProvider>) -> Void) = unreachable("MFA request has to be assigned before use.")

    let emptySessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, TheError> = Just(Void())
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()

    let sessionVariablePublisher: AnyPublisher<AuthorizedSessionVariable, TheError> =
      sessionSubject
      .combineLatest(tokensSubject.switchToLatest())
      .map {
        (session: NetworkSessionVariable?, tokens: NetworkClient.Tokens?) -> AnyPublisher<
          AuthorizedSessionVariable, TheError
        > in
        if let session: NetworkSessionVariable = session,
          let authorizationToken: String = tokens?.accessToken,
          !(tokens?.isExpired() ?? true)
        {
          return Just(
            AuthorizedSessionVariable(
              domain: session.domain,
              authorizationToken: authorizationToken
            )
          )
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
        }
        else {
          #warning("""
          TODO: [PAS-160]
          - trigger session refresh if expired or when token is missing
          we might however react on specific error
          in order to trigger it from given context - to verify
          """)

          // Currently there's no session refresh
          authorizationRequest()
          return Fail<AuthorizedSessionVariable, TheError>(error: .missingSession())
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    let domainVariablePublisher: AnyPublisher<DomainSessionVariable, TheError> =
      sessionSubject
      .map { session -> AnyPublisher<DomainSessionVariable, TheError> in
        if let session: NetworkSessionVariable = session {
          return Just(DomainSessionVariable(domain: session.domain))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        else {
          return Fail<DomainSessionVariable, TheError>(error: .missingSession())
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    func setTokens(publisher: AnyPublisher<Tokens?, Never>) {
      tokensSubject.send(publisher)
    }

    func setAuthorizationRequest(_ request: @escaping () -> Void) {
      authorizationRequest = request
    }

    func setMFARequest(_ request: @escaping (Array<MFAProvider>) -> Void) {
      mfaRequest = request
    }

    func requestAuthorization() {
      authorizationRequest()
    }

    func requestMFA(with providers: Array<MFAProvider>) {
      mfaRequest(providers)
    }

    return Self(
      accountTransferUpdate: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      mediaDownload: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      serverPGPPublicKeyRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      serverPublicKeyRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      serverRSAPublicKeyRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      signInRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      signOutRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      refreshSessionRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      configRequest: .live(
        using: networking,
        with: domainVariablePublisher
      ),
      resourcesRequest: .live(
        using: networking,
        with: sessionVariablePublisher
      )
      .withAuthErrors(
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA
      ),
      resourcesTypesRequest: .live(
        using: networking,
        with: sessionVariablePublisher
      )
      .withAuthErrors(
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA
      ),
      resourceSecretRequest: .live(
        using: networking,
        with: sessionVariablePublisher
      )
      .withAuthErrors(
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA
      ),
      totpAuthorizationRequest: .live(
        using: networking,
        with: sessionVariablePublisher
      )
      .withAuthErrors(
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA
      ),
      yubikeyAuthorizationRequest: .live(
        using: networking,
        with: sessionVariablePublisher
      )
      .withAuthErrors(
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA
      ),
      updateSession: sessionSubject.send(_:),
      setTokensPublisher: setTokens(publisher:),
      setAuthorizationRequest: setAuthorizationRequest(_:),
      setMFARequest: setMFARequest(_:)
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      accountTransferUpdate: .placeholder,
      mediaDownload: .placeholder,
      serverPGPPublicKeyRequest: .placeholder,
      serverPublicKeyRequest: .placeholder,
      serverRSAPublicKeyRequest: .placeholder,
      signInRequest: .placeholder,
      signOutRequest: .placeholder,
      refreshSessionRequest: .placeholder,
      configRequest: .placeholder,
      resourcesRequest: .placeholder,
      resourcesTypesRequest: .placeholder,
      resourceSecretRequest: .placeholder,
      totpAuthorizationRequest: .placeholder,
      yubikeyAuthorizationRequest: .placeholder,
      updateSession: Commons.placeholder("You have to provide mocks for used methods"),
      setTokensPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setAuthorizationRequest: Commons.placeholder("You have to provide mocks for used methods"), 
      setMFARequest: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
