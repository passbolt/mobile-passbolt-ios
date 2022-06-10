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

  public var authorizeUsingYubikey: @AccountSessionActor (Bool) -> AnyPublisher<Void, Error>
  public var authorizeUsingTOTP: @AccountSessionActor (String, Bool) -> AnyPublisher<Void, Error>
}

extension MFA: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> MFA {
    let yubikey: Yubikey = environment.yubikey
    let accountSession: AccountSession = try await features.instance()

    @AccountSessionActor func authorizeUsingYubikey(saveLocally: Bool) -> AnyPublisher<Void, Error> {
      return
        yubikey
        .readNFC()
        .eraseErrorType()
        .map { otp in
          cancellables.executeOnAccountSessionActorWithPublisher {
            try await accountSession.mfaAuthorize(.yubikeyOTP(otp), saveLocally)
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    @AccountSessionActor func authorizeUsingOTP(totp: String, saveLocally: Bool) -> AnyPublisher<Void, Error> {
      cancellables.executeOnAccountSessionActorWithPublisher {
        try await accountSession.mfaAuthorize(.totp(totp), saveLocally)
      }
    }

    return Self(
      authorizeUsingYubikey: authorizeUsingYubikey(saveLocally:),
      authorizeUsingTOTP: authorizeUsingOTP(totp:saveLocally:)
    )
  }
}

extension MFA {

  public var featureUnload: @FeaturesActor () async throws -> Void { {} }
}

#if DEBUG
extension MFA {

  public static var placeholder: MFA {
    Self(
      authorizeUsingYubikey: unimplemented("You have to provide mocks for used methods"),
      authorizeUsingTOTP: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
