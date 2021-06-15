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
  public var featureUnload: () -> Bool
  public var updateSession: (NetworkSessionVariable?) -> Void
  public var setTokensPublisher: (AnyPublisher<Tokens?, Never>) -> Void
}

extension NetworkClient {
  
  public typealias Tokens = (
    accessToken: String,
    isExpired: () -> Bool,
    refreshToken: String
  )
}

extension NetworkClient: Feature {
  
  public typealias Environment = Networking
  
  public static func load(
    in environment: (Networking),
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let sessionSubject: CurrentValueSubject<NetworkSessionVariable?, Never> = .init(nil)
    let tokensSubject: CurrentValueSubject<AnyPublisher<Tokens?, Never>, Never> = .init(Empty().eraseToAnyPublisher())

    let emptySessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, TheError> = Just(Void())
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    
    let sessionVariablePublisher: AnyPublisher<AuthorizedSessionVariable, TheError> = sessionSubject
      .combineLatest(tokensSubject.switchToLatest())
      .map { (session: NetworkSessionVariable?, tokens: NetworkClient.Tokens?) -> AnyPublisher<AuthorizedSessionVariable, TheError> in
        if let session: NetworkSessionVariable = session,
          let authorizationToken: String = tokens?.accessToken,
           !(tokens?.isExpired() ?? true) {
          return Just(
            AuthorizedSessionVariable(
              domain: session.domain,
              authorizationToken: authorizationToken
            )
          )
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
        } else {
          #warning("TODO - PAS-160 - trigger session refresh if expired or when token is missing")
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
        } else {
          return Fail<DomainSessionVariable, TheError>(error: .missingSession())
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    func featureUnload() -> Bool {
      true // perform cleanup if needed
    }
    
    func setTokens(publisher: AnyPublisher<Tokens?, Never>) {
      tokensSubject.send(publisher)
    }

    return Self(
      accountTransferUpdate: .live(
        using: environment,
        with: emptySessionVariablePublisher
      ),
      mediaDownload: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      serverPGPPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      serverPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      serverRSAPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      signInRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      signOutRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      refreshSessionRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      featureUnload: featureUnload,
      updateSession: sessionSubject.send(_:),
      setTokensPublisher: setTokens(publisher:)
    )
  }
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    rootEnvironment.networking
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
      featureUnload: Commons.placeholder("You have to provide mocks for used methods"),
      updateSession: Commons.placeholder("You have to provide mocks for used methods"),
      setTokensPublisher: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
