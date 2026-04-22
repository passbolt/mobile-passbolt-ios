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
import Session

internal final class YubiKeyViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var alert: AlertViewModel?
    internal var rememberDevice: Bool = true
  }

  internal nonisolated let viewState: ViewStateSource<ViewState> = .init(initial: .init())
  private let session: Session

  internal init(context: (), features: Features) throws {
    session = try features.instance()
  }

  internal func startScanning() async {
    let rememberDevice = await self.viewState.current.rememberDevice
    do {
      try await session
        .authorizeMFA(
          .yubiKey(
            session.currentAccount(),
            rememberDevice: rememberDevice
          )
        )
    }
    catch {
      if let error = error as? NetworkRequestValidationFailure,
        let body = error.validationViolations["body"] as? Dictionary<String, Any>,
        let hotp = body["hotp"] as? Dictionary<String, Any>,
        hotp["isSameYubikeyId"] as? String != nil
      {
        self.viewState.update(
          \.alert,
          to: .init(
            title: "yubiKey.scan.notRecognized.title",
            message: "yubiKey.scan.notRecognized.message",
            actions: [
              .regular(
                id: .init(),
                title: "yubiKey.scan.notRecognized.button.ok",
                perform: {
                  /** no-op */
                }
              )
            ]
          )
        )
      }
      else {
        SnackBarMessageEvent.send(.error(error))
      }
    }
  }
}
