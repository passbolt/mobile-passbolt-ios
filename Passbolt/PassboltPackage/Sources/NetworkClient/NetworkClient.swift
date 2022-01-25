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
  public var userProfileRequest: UserProfileRequest
  public var createResourceRequest: CreateResourceRequest
  public var updateResourceRequest: UpdateResourceRequest
  public var deleteResourceRequest: DeleteResourceRequest
  public var userListRequest: UserListRequest
  public var appVersionsAvailableRequest: AppVersionsAvailableRequest
  public var setSessionStatePublisher: (AnyPublisher<SessionState?, Never>) -> Void
  public var setAccessTokenInvalidation: (@escaping () -> Void) -> Void
  public var setAuthorizationRequest: (@escaping () -> Void) -> Void
  public var setMFARequest: (@escaping (Array<MFAProvider>) -> Void) -> Void
}

extension NetworkClient {

  public typealias SessionState = (
    domain: URLString,
    accessToken: String?,
    mfaToken: String?
  )
}

extension NetworkClient: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let networking: Networking = environment.networking

    let sessionStatePublisherSubject: CurrentValueSubject<AnyPublisher<SessionState?, Never>, Never> =
      .init(PassthroughSubject().eraseToAnyPublisher())
    let sessionStatePublisher: AnyPublisher<SessionState?, Never> =
      sessionStatePublisherSubject
      .switchToLatest()
      .eraseToAnyPublisher()

    // accessed without lock - always set during loading initial features, before use
    var accessTokenInvalidaton: (() -> Void) = unreachable(
      "Access token invalidaton method has to be assigned before use."
    )
    // accessed without lock - always set during loading initial features, before use
    var authorizationRequest: (() -> Void) = unreachable("Authorization request has to be assigned before use.")
    // accessed without lock - always set during loading initial features, before use
    var mfaRequest: ((Array<MFAProvider>) -> Void) = unreachable("MFA request has to be assigned before use.")
    let emptySessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, Error> = Just(Void())
      .eraseErrorType()
      .eraseToAnyPublisher()

    let authorizedNetworkSessionVariablePublisher: AnyPublisher<AuthorizedNetworkSessionVariable, Error> =
      sessionStatePublisher
      .map { (sessionState: SessionState?) -> AnyPublisher<AuthorizedNetworkSessionVariable?, Error> in
        guard let sessionState: SessionState = sessionState
        else {
          return Fail(error: SessionMissing.error())
            .eraseToAnyPublisher()
        }
        if let accessToken: String = sessionState.accessToken {
          return Just(
            AuthorizedNetworkSessionVariable(
              domain: sessionState.domain,
              accessToken: accessToken,
              mfaToken: sessionState.mfaToken
            )
          )
          .eraseErrorType()
          .eraseToAnyPublisher()
        }
        else {
          requestAuthorization()
          return Just(nil)  // it will wait for the authorization
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .filterMapOptional()
      .eraseToAnyPublisher()

    let domainNetworkSessionVariablePublisher: AnyPublisher<DomainNetworkSessionVariable, Error> =
      sessionStatePublisher
      .map { sessionState -> AnyPublisher<DomainNetworkSessionVariable, Error> in
        if let sessionState: SessionState = sessionState {
          return Just(DomainNetworkSessionVariable(domain: sessionState.domain))
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
        else {
          return Fail(error: SessionMissing.error())
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    func setSessionStatePublisher(
      _ sessionStatePublisher: AnyPublisher<SessionState?, Never>
    ) {
      sessionStatePublisherSubject.send(sessionStatePublisher)
    }

    func setAccessTokenInvalidation(
      method: @escaping () -> Void
    ) {
      accessTokenInvalidaton = method
    }

    func setAuthorization(
      request: @escaping () -> Void
    ) {
      authorizationRequest = request
    }

    func setMFA(
      request: @escaping (Array<MFAProvider>) -> Void
    ) {
      mfaRequest = request
    }

    func invalidateAccessToken() {
      accessTokenInvalidaton()
    }

    func requestAuthorization() {
      authorizationRequest()
    }

    func requestMFA(with providers: Array<MFAProvider>) {
      mfaRequest(providers)
    }

    let mfaRedirectRequest: MFARedirectRequest = .live(
      using: networking,
      with: authorizedNetworkSessionVariablePublisher
    )

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
        with: emptySessionVariablePublisher
      ),
      serverPublicKeyRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      serverRSAPublicKeyRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      signInRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      signOutRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      refreshSessionRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      configRequest: .live(
        using: networking,
        with: domainNetworkSessionVariablePublisher
      ),
      resourcesRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      resourcesTypesRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      resourceSecretRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      totpAuthorizationRequest: .live(
        using: networking,
        with: domainNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      yubikeyAuthorizationRequest: .live(
        using: networking,
        with: domainNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      userProfileRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      createResourceRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      updateResourceRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      deleteResourceRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      userListRequest: .live(
        using: networking,
        with: authorizedNetworkSessionVariablePublisher
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      appVersionsAvailableRequest: .live(
        using: networking,
        with: emptySessionVariablePublisher
      ),
      setSessionStatePublisher: setSessionStatePublisher(_:),
      setAccessTokenInvalidation: setAccessTokenInvalidation(method:),
      setAuthorizationRequest: setAuthorization(request:),
      setMFARequest: setMFA(request:)
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
      userProfileRequest: .placeholder,
      createResourceRequest: .placeholder,
      updateResourceRequest: .placeholder,
      deleteResourceRequest: .placeholder,
      userListRequest: .placeholder,
      appVersionsAvailableRequest: .placeholder,
      setSessionStatePublisher: unimplemented("You have to provide mocks for used methods"),
      setAccessTokenInvalidation: unimplemented("You have to provide mocks for used methods"),
      setAuthorizationRequest: unimplemented("You have to provide mocks for used methods"),
      setMFARequest: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
