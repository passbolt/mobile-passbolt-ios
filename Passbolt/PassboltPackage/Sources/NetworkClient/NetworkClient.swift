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
  public var userProfileRequest: UserProfileRequest
  public var createResourceRequest: CreateResourceRequest
  public var updateResourceRequest: UpdateResourceRequest
  public var deleteResourceRequest: DeleteResourceRequest
  public var userListRequest: UserListRequest
  public var setSessionStatePublisher: (AnyPublisher<SessionState?, Never>) -> Void
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
    var authorizationRequest: (() -> Void) = unreachable("Authorization request has to be assigned before use.")
    // accessed without lock - always set during loading initial features, before use
    var mfaRequest: ((Array<MFAProvider>) -> Void) = unreachable("MFA request has to be assigned before use.")
    let emptySessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, TheError> = Just(Void())
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()

    let authorizedNetworkSessionVariablePublisher: AnyPublisher<AuthorizedNetworkSessionVariable, TheError> =
      sessionStatePublisher
      .map { (sessionState: SessionState?) -> AnyPublisher<AuthorizedNetworkSessionVariable?, TheError> in
        guard let sessionState: SessionState = sessionState
        else {
          return Fail(error: .missingSession())
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
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
        }
        else {
          requestAuthorization()
          return Just(nil)  // it will wait for the authorization
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .filterMapOptional()
      .eraseToAnyPublisher()

    let domainNetworkSessionVariablePublisher: AnyPublisher<DomainNetworkSessionVariable, TheError> =
      sessionStatePublisher
      .map { sessionState -> AnyPublisher<DomainNetworkSessionVariable, TheError> in
        if let sessionState: SessionState = sessionState {
          return Just(DomainNetworkSessionVariable(domain: sessionState.domain))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        else {
          return Fail(error: .missingSession())
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
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionPublisher: domainNetworkSessionVariablePublisher
      ),
      setSessionStatePublisher: setSessionStatePublisher(_:),
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
      setSessionStatePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setAuthorizationRequest: Commons.placeholder("You have to provide mocks for used methods"),
      setMFARequest: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
