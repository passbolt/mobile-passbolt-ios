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

#warning("TODO: session management: [PAS-154]")
public struct NetworkClient {
  
  public var accountTransferUpdate: AccountTransferUpdateRequest
  // intended to be used for images download and relatively small blobs (few MB)
  public var mediaDownload: MediaDownloadRequest
  public var serverPgpPublicKeyRequest: ServerPgpPublicKeyRequest
  public var serverPublicKeyRequest: ServerJWKSRequest
  public var serverRsaPublicKeyRequest: ServerRSAPublicKeyRequest
  public var loginRequest: LoginRequest
  public var featureUnload: () -> Bool
  public var updateSession: (NetworkSessionVariable?) -> Void
}

extension NetworkClient: Feature {
  
  public typealias Environment = Networking
  
  public static func load(
    in environment: (Networking),
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let sessionSubject: CurrentValueSubject<NetworkSessionVariable?, Never> = .init(nil)

    let emptySessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, TheError> = Just(Void())
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    let _: AnyPublisher<NetworkSessionVariable, TheError> = sessionSubject
      .map { session -> AnyPublisher<NetworkSessionVariable, TheError> in
        if let session: NetworkSessionVariable = session {
          return Just(session)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        } else {
          #warning("FIXME - PAS-131 - change this error to new error type")
          return Fail<NetworkSessionVariable, TheError>(error: .canceled)
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
          #warning("FIXME - PAS-131 - change this error to new error type")
          return Fail<DomainSessionVariable, TheError>(error: .canceled)
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    func featureUnload() -> Bool {
      true // perform cleanup if needed
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
      serverPgpPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      serverPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      serverRsaPublicKeyRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      loginRequest: .live(
        using: environment,
        with: domainVariablePublisher
      ),
      featureUnload: featureUnload,
      updateSession: sessionSubject.send(_:)
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
      serverPgpPublicKeyRequest: .placeholder,
      serverPublicKeyRequest: .placeholder,
      serverRsaPublicKeyRequest: .placeholder,
      loginRequest: .placeholder,
      featureUnload: Commons.placeholder("You have to provide mocks for used methods"),
      updateSession: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
