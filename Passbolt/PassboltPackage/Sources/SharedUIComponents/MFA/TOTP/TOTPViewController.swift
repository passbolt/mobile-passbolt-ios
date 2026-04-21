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

import Display
import OSFeatures
import Session

internal final class TOTPViewController: ViewController {

  internal struct Context {
    var loadingCallback: (Bool) -> Void
  }

  internal static let otpLength: Int = 6

  internal struct ViewState: Equatable {
    internal var rememberDevice: Bool = true
    internal var otp: String = ""
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  private let pasteboard: OSPasteboard
  private let session: Session
  private let loadingCallback: (Bool) -> Void

  internal init(context: Context, features: Features) throws {
    self.loadingCallback = context.loadingCallback
    self.pasteboard = features.instance()
    self.session = try features.instance()
    self.viewState = .init(
      initial: .init()
    )
  }

  internal func pasteOTP() {
    if let pasted: String = pasteboard.get(),
      pasted.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted)?.isEmpty ?? true,
      pasted.count == Self.otpLength
    {
      viewState.update(\.otp, to: pasted)
      Task {
        await verifyCode()
      }
    }
    else {
      handle(error: InvalidPasteValue.error())
    }
  }

  func otpEntered(_ otp: String) {
    viewState.update(\.otp, to: otp)
    Task {
      await verifyCode()
    }
  }

  internal func verifyCode() async {
    loadingCallback(true)
    defer {
      loadingCallback(false)
    }
    let currentState: ViewState = await viewState.current
    do {
      try await session
        .authorizeMFA(
          .totp(
            session.currentAccount(),
            code: currentState.otp,
            rememberDevice: currentState.rememberDevice
          )
        )
    }
    catch {
      handle(error: error)
    }
  }

  private func handle(error: Error) {
    switch error {
    case is InvalidPasteValue:
      SnackBarMessageEvent.send(.error(.localized(key: .invalidPasteValue)))
    case is NetworkRequestValidationFailure:
      SnackBarMessageEvent.send(.error("totp.wrong.code.error"))

    case is Cancelled:
      break  // actually not an error
    default:
      SnackBarMessageEvent.send(.error(error))
    }
  }
}
