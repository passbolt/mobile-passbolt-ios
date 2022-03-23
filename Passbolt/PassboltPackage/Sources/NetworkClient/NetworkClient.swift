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
import Features

public struct NetworkClient {

  public var accountTransferUpdate: AccountTransferUpdateRequest
  // intended to be used for images download and relatively small blobs (few MB)
  public var mediaDownload: MediaDownloadRequest
  public var serverPGPPublicKeyRequest: ServerPGPPublicKeyRequest
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
  public var foldersRequest: FoldersRequest
  public var appVersionsAvailableRequest: AppVersionsAvailableRequest
  public var setSessionStateSource:
    @AccountSessionActor (@AccountSessionActor @escaping () async throws -> SessionState?) -> Void
  public var setAccessTokenInvalidation:
    @AccountSessionActor (@AccountSessionActor @escaping () async throws -> Void) -> Void
  public var setAuthorizationRequest:
    @AccountSessionActor (@AccountSessionActor @escaping () async throws -> Void) -> Void
  public var setMFARequest:
    @AccountSessionActor (@AccountSessionActor @escaping (Array<MFAProvider>) async throws -> Void) -> Void
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
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let networking: Networking = environment.networking

    // set during loading initial features, before use
    var sessionStateSource: @AccountSessionActor () async throws -> SessionState? = unreachable(
      "Session state source method has to be assigned before use."
    )
    // set during loading initial features, before use
    var accessTokenInvalidaton: (@AccountSessionActor () async throws -> Void) = unreachable(
      "Access token invalidaton method has to be assigned before use."
    )
    // set during loading initial features, before use
    var authorizationRequest: (@AccountSessionActor () async throws -> Void) = unreachable(
      "Authorization request has to be assigned before use."
    )
    // set during loading initial features, before use
    var mfaRequest: (@AccountSessionActor (Array<MFAProvider>) async throws -> Void) = unreachable(
      "MFA request has to be assigned before use."
    )

    @AccountSessionActor func setSessionStateSource(
      _ sessionState: @AccountSessionActor @escaping () async throws -> SessionState?
    ) {
      sessionStateSource = sessionState
    }

    @AccountSessionActor func setAccessTokenInvalidation(
      _ method: @AccountSessionActor @escaping () async throws -> Void
    ) {
      accessTokenInvalidaton = method
    }

    @AccountSessionActor func setAuthorizationRequest(
      _ request: @AccountSessionActor @escaping () async throws -> Void
    ) {
      authorizationRequest = request
    }

    @AccountSessionActor func setMFARequest(
      _ request: @AccountSessionActor @escaping (Array<MFAProvider>) async throws -> Void
    ) {
      mfaRequest = request
    }

    @AccountSessionActor func emptySession() async throws -> EmptyNetworkSessionVariable {
      EmptyNetworkSessionVariable()
    }

    @AccountSessionActor func currentSessionState() async throws -> SessionState {
      if let sessionState: SessionState = try await sessionStateSource() {
        return sessionState
      }
      else {
        throw SessionMissing.error()
      }
    }

    @AccountSessionActor func currentAuthorizedSessionState() async throws -> AuthorizedNetworkSessionVariable {
      let sessionState: SessionState = try await currentSessionState()

      if let accessToken: String = sessionState.accessToken {
        return AuthorizedNetworkSessionVariable(
          domain: sessionState.domain,
          accessToken: accessToken,
          mfaToken: sessionState.mfaToken
        )
      }
      else {
        // TODO: wait for authorization
        // it might update session state
        // and allow to finish correctly
        try await requestAuthorization()
        throw SessionMissing.error()
      }
    }

    @AccountSessionActor func currentDomainSessionState() async throws -> DomainNetworkSessionVariable {
      try await DomainNetworkSessionVariable(
        domain: currentSessionState().domain
      )
    }

    @AccountSessionActor func invalidateAccessToken() async throws {
      try await accessTokenInvalidaton()
    }

    @AccountSessionActor func requestAuthorization() async throws {
      try await authorizationRequest()
    }

    @AccountSessionActor func requestMFA(with providers: Array<MFAProvider>) async throws {
      try await mfaRequest(providers)
    }

    let mfaRedirectRequest: MFARedirectRequest = .live(
      using: networking,
      with: currentAuthorizedSessionState
    )

    return Self(
      accountTransferUpdate: .live(
        using: networking,
        with: emptySession
      ),
      mediaDownload: .live(
        using: networking,
        with: emptySession
      ),
      serverPGPPublicKeyRequest: .live(
        using: networking,
        with: emptySession
      ),
      serverRSAPublicKeyRequest: .live(
        using: networking,
        with: emptySession
      ),
      signInRequest: .live(
        using: networking,
        with: emptySession
      ),
      signOutRequest: .live(
        using: networking,
        with: emptySession
      ),
      refreshSessionRequest: .live(
        using: networking,
        with: emptySession
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      configRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      resourcesRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      resourcesTypesRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      resourceSecretRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      totpAuthorizationRequest: .live(
        using: networking,
        with: currentDomainSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      yubikeyAuthorizationRequest: .live(
        using: networking,
        with: currentDomainSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      userProfileRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      createResourceRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      updateResourceRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      deleteResourceRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      userListRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      foldersRequest: .live(
        using: networking,
        with: currentAuthorizedSessionState
      )
      .withAuthErrors(
        invalidateAccessToken: invalidateAccessToken,
        authorizationRequest: requestAuthorization,
        mfaRequest: requestMFA,
        mfaRedirectionHandler: mfaRedirectRequest.execute,
        sessionVariable: currentDomainSessionState
      ),
      appVersionsAvailableRequest: .live(
        using: networking,
        with: emptySession
      ),
      setSessionStateSource: setSessionStateSource(_:),
      setAccessTokenInvalidation: setAccessTokenInvalidation(_:),
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
      foldersRequest: .placeholder,
      appVersionsAvailableRequest: .placeholder,
      setSessionStateSource: unimplemented("You have to provide mocks for used methods"),
      setAccessTokenInvalidation: unimplemented("You have to provide mocks for used methods"),
      setAuthorizationRequest: unimplemented("You have to provide mocks for used methods"),
      setMFARequest: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension NetworkClient {

  public var featureUnload: @FeaturesActor () async throws -> Void { {} }
}
