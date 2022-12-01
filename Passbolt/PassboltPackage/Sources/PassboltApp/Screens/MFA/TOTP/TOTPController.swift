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
import Session
import UIComponents

internal struct TOTPController {

  internal var statusChangePublisher: @MainActor () -> AnyPublisher<StatusChange, Never>
  internal var otpPublisher: @MainActor () -> AnyPublisher<String, Never>
  internal var setOTP: @MainActor (String) -> Void
  internal var pasteOTP: @MainActor () -> Void
  internal var rememberDevicePublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var toggleRememberDevice: @MainActor () -> Void
}

extension TOTPController {

  internal static let otpLength: Int = 6

  internal enum StatusChange {
    case idle
    case processing
    case error(Error)
  }
}

extension TOTPController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let session: Session = try await features.instance()
    let pasteboard: Pasteboard = try await features.instance()

    let statusChangeSubject: PassthroughSubject<StatusChange, Never> = .init()
    let otpSubject: CurrentValueSubject<String, Never> = .init("")
    let rememberDeviceSubject: CurrentValueSubject<Bool, Never> = .init(true)

    otpSubject
      .combineLatest(rememberDeviceSubject)
      .removeDuplicates(by: { prev, next in
        prev.0 == next.0
          && prev.1 == next.1
      })
      .compactMap { (otp, rememberDevice) -> AnyPublisher<Void, Never>? in
        if otp.count == Self.otpLength {
          statusChangeSubject.send(.processing)
          return cancellables.executeAsyncWithPublisher {
            do {
              try await session
                .authorizeMFA(
                  .totp(
                    session.currentAccount(),
                    otp,
                    rememberDevice: rememberDevice
                  )
                )
              statusChangeSubject.send(.idle)
            }
            catch is CancellationError, is Cancelled {
              statusChangeSubject.send(.idle)
            }
            catch {
              statusChangeSubject.send(.error(error))
            }
          }
          .replaceError(with: Void())
          .eraseToAnyPublisher()
        }
        else {
          return nil
        }
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)

    func statusChangePublisher() -> AnyPublisher<StatusChange, Never> {
      statusChangeSubject.eraseToAnyPublisher()
    }

    func otpPublisher() -> AnyPublisher<String, Never> {
      otpSubject.removeDuplicates().eraseToAnyPublisher()
    }

    func setOTP(_ otp: String) {
      otpSubject.value = otp
    }

    func pasteOTP() {
      if let pasted: String = pasteboard.get(),
        pasted.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted)?.isEmpty ?? true,
        pasted.count == Self.otpLength
      {
        otpSubject.value = pasted
      }
      else {
        statusChangeSubject.send(.error(InvalidPasteValue.error()))
      }
    }

    func rememberDevicePublisher() -> AnyPublisher<Bool, Never> {
      rememberDeviceSubject.removeDuplicates().eraseToAnyPublisher()
    }

    func toggleRememberDevice() {
      rememberDeviceSubject.value.toggle()
    }

    return Self(
      statusChangePublisher: statusChangePublisher,
      otpPublisher: otpPublisher,
      setOTP: setOTP(_:),
      pasteOTP: pasteOTP,
      rememberDevicePublisher: rememberDevicePublisher,
      toggleRememberDevice: toggleRememberDevice
    )
  }
}
