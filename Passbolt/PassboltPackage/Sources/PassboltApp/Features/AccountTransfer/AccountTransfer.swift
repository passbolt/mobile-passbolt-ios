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

import Features
import Networking

import class Foundation.RunLoop

public struct AccountTransfer {
  
  public var transferProgressPublisher: () -> AnyPublisher<TransferProgress, TheError>
  public var processPayload: (String) -> AnyPublisher<Void, TheError>
  public var cancelTransfer: () -> Void
}

extension AccountTransfer: Feature {
  
  public typealias Environment = Networking
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    rootEnvironment.networking
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory
  ) -> AccountTransfer {
    let transferState: CurrentValueSubject<AccountTransferState, TheError> = .init(.init())
    
    return Self(
      transferProgressPublisher: transferState
        .map { state -> TransferProgress in
          guard let configuration = state.configuration
          else { return .configuration }
          
          return .progress(
            currentPage: state.currentPage,
            pagesCount: configuration.pagesCount
          )
        }
        .eraseToAnyPublisher,
      processPayload: { payload in
        #warning("TODO: [PAS-71] - complete data processing")
        // don't forget to complete transferState publisher and unload feature when all parts become processed
        return Fail<Void, TheError>(error: .accountTransfer())
          .delay(for: 2, scheduler: RunLoop.main)
          .eraseToAnyPublisher()
      },
      cancelTransfer: { [weak features] in
        #warning("TODO: [PAS-71] - ensure processing cancelation")
        transferState.send(completion: .failure(.canceled))
        features?.unload(AccountTransfer.self)
      }
    )
  }
  
  public func unload() -> Bool {
    true // we should unload this feature after use and it always succeeds
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      transferProgressPublisher: Commons.placeholder("You have to provide mocks for used methods "),
      processPayload: Commons.placeholder("You have to provide mocks for used methods "),
      cancelTransfer: Commons.placeholder("You have to provide mocks for used methods ")
    )
  }
  #endif
}

extension AccountTransfer {
  
  public enum TransferProgress {
    
    case configuration
    case progress(currentPage: Int, pagesCount: Int)
  }
}
