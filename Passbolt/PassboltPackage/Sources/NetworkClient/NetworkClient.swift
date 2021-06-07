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

import Accounts
import Commons
import Features

#warning("TODO: session management: [PAS-131]")
public struct NetworkClient {
  
  public var accountTransferUpdate: AccountTransferUpdateRequest
  // intended to be used for images download and relatively small blobs (few MB)
  public var mediaDownload: MediaDownloadRequest
  public var featureUnload: () -> Bool
}

extension NetworkClient: Feature {
  
  public typealias Environment = Networking
  
  public static func load(
    in environment: (Networking),
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> NetworkClient {
    let session: AccountSession = features.instance()
    let emptySessionVariablePubliher: AnyPublisher<EmptyNetworkSessionVariable, TheError> = Just(Void())
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    let sessionVariablePublisher: AnyPublisher<NetworkSessionVariable, TheError> = session
      .statePublisher()
      .map { sessionState -> AnyPublisher<NetworkSessionVariable, TheError> in
        switch sessionState {
        // swiftlint:disable:next explicit_type_interface
        case let .authorized(account, token), let .authorizationRequired(account, .some(token)):
          return Just(
            NetworkSessionVariable(
              domain: account.domain,
              authorizationToken: token.rawValue
            )
          )
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
          
        case .authorizationRequired, .none:
          #warning("TODO: [PAS-69] Change error")
          return Fail<NetworkSessionVariable, TheError>(error: .sessionClosed())
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
        with: emptySessionVariablePubliher
      ),
      mediaDownload: .live(
        using: environment,
        with: sessionVariablePublisher
      ),
      featureUnload: featureUnload
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
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
