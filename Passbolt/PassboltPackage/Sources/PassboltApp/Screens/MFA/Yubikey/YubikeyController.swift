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
import Session
import UIComponents

internal struct YubiKeyController {

  internal var toggleRememberDevice: @MainActor () -> Void
  internal var rememberDevicePublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var authorizeUsingOTP: @MainActor () -> AnyPublisher<Void, Error>
}

extension YubiKeyController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> YubiKeyController {
    let session: Session = try await features.instance()
    let rememberDeviceSubject: CurrentValueSubject<Bool, Never> = .init(true)

    func toggleRememberDevice() {
      rememberDeviceSubject.value.toggle()
    }

    func rememberDevicePublisher() -> AnyPublisher<Bool, Never> {
      rememberDeviceSubject.removeDuplicates().eraseToAnyPublisher()
    }

    func authorizeUsingOTP() -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        try await session
          .authorizeMFA(
            .yubiKey(
              session.currentAccount(),
              rememberDevice: rememberDeviceSubject.value
            )
          )
      }
      .eraseToAnyPublisher()
    }

    return Self(
      toggleRememberDevice: toggleRememberDevice,
      rememberDevicePublisher: rememberDevicePublisher,
      authorizeUsingOTP: authorizeUsingOTP
    )
  }
}
