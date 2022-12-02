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

public struct OSLinkOpener {

  public var openURL: (URL) -> AnyPublisher<Bool, Never>
  public var openAppSettings: () -> AnyPublisher<Bool, Never>
  public var openSystemSettings: () -> AnyPublisher<Bool, Never>
}

extension OSLinkOpener: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      openURL: unimplemented(),
      openAppSettings: unimplemented(),
      openSystemSettings: unimplemented()
    )
  }
  #endif
}

extension OSLinkOpener {

  // Legacy implementation
  fileprivate static var live: Self {
    func open(url: URL) -> AnyPublisher<Bool, Never> {
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
      openURL: open(url:),
      openAppSettings: {
        // swift-format-ignore: NeverForceUnwrap
        open(url: URL(string: UIApplication.openSettingsURLString)!)
      },
      openSystemSettings: {
        // swift-format-ignore: NeverForceUnwrap
        open(url: URL(string: "App-prefs:")!)
      }
    )
  }
}

extension FeatureFactory {

  internal func useOSLinkOpener() {
    self.use(
      OSLinkOpener.live
    )
  }
}
