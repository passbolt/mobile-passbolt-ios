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

public struct MFA {

  public var authorizeUsingYubikey: (Bool) -> AnyPublisher<Void, TheError>
  public var authorizeUsingTOTP: (String, Bool) -> AnyPublisher<Void, TheError>
}

extension MFA: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables) -> MFA {

    let yubikey: Yubikey = environment.yubikey
    let accountSession: AccountSession = features.instance()
    let networkSession: NetworkSession = features.instance()

    func authorizeUsingYubikey(saveLocally: Bool) -> AnyPublisher<Void, TheError> {
      accountSession.statePublisher()
        .map { state -> AnyPublisher<Void, TheError> in
          switch state {
          case let .authorizedMFARequired(account), let .authorized(account):
            return yubikey.readNFC()
              .map { otp in
                networkSession.createMFAToken(account, .yubikeyOTP(otp), saveLocally)
              }
              .switchToLatest()
              .eraseToAnyPublisher()
          case .none, .authorizationRequired:
            return Fail(error: .authorizationRequired())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func authorizeUsingOTP(totp: String, saveLocally: Bool) -> AnyPublisher<Void, TheError> {
      accountSession.statePublisher()
        .map { state -> AnyPublisher<Void, TheError> in
          switch state {
          case let .authorizedMFARequired(account), let .authorized(account):
            return networkSession.createMFAToken(account, .totp(totp), saveLocally)
          case .none, .authorizationRequired:
            return Fail(error: .authorizationRequired())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      authorizeUsingYubikey: authorizeUsingYubikey(saveLocally:),
      authorizeUsingTOTP: authorizeUsingOTP(totp:saveLocally:)
    )
  }
}

#if DEBUG
extension MFA {

  public static var placeholder: MFA {
    Self(
      authorizeUsingYubikey: Commons.placeholder("You have to provide mocks for used methods"),
      authorizeUsingTOTP: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
