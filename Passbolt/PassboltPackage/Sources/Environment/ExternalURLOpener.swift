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

import Combine
import CommonModels
import UIKit

import struct Foundation.URL

public struct ExternalURLOpener: EnvironmentElement {

  public var openLink: (URL) -> AnyPublisher<Bool, Never>
  public var openAppSettings: () -> AnyPublisher<Bool, Never>
  public var openSystemSettings: () -> AnyPublisher<Bool, Never>
}

extension ExternalURLOpener {

  public static func live() -> Self {
    let openUrl: (URL) -> AnyPublisher<Bool, Never> = { (url: URL) -> AnyPublisher<Bool, Never> in
      let openResultSubject: PassthroughSubject<Bool, Never> = .init()
      DispatchQueue.main.async {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(
            url,
            completionHandler: { success in
              openResultSubject.send(success)
              openResultSubject.send(completion: .finished)
            }
          )
        }
        else {
          openResultSubject.send(false)
          openResultSubject.send(completion: .finished)
        }
      }
      return openResultSubject.eraseToAnyPublisher()
    }

    return Self(
      openLink: openUrl,
      openAppSettings: {
        // swift-format-ignore: NeverForceUnwrap
        openUrl(URL(string: UIApplication.openSettingsURLString)!)
      },
      openSystemSettings: {
        // swift-format-ignore: NeverForceUnwrap
        openUrl(URL(string: "App-prefs:")!)
      }
    )
  }
}

extension Environment {

  public var externalURLOpener: ExternalURLOpener {
    get { element(ExternalURLOpener.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension ExternalURLOpener {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      openLink: unimplemented("You have to provide mocks for used methods"),
      openAppSettings: unimplemented("You have to provide mocks for used methods"),
      openSystemSettings: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
