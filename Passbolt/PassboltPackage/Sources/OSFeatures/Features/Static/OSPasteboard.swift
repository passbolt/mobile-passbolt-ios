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

import UIKit.UIPasteboard

public struct OSPasteboard {

  public var get: () -> String?
  public var put: (String?) -> Void
  public var putWithAutoExpiration: (String?) -> Void
}

extension OSPasteboard {

  public func put(_ value: String?, withAutoExpiration: Bool) {
    if withAutoExpiration {
      self.putWithAutoExpiration(value)
    }
    else {
      self.put(value)
    }
  }
}

extension OSPasteboard: StaticFeature {

  #if DEBUG
  public static var placeholder: OSPasteboard {
    Self(
      get: unimplemented0(),
      put: unimplemented1(),
      putWithAutoExpiration: unimplemented1()
    )
  }
  #endif
}

extension OSPasteboard {

  private static var expirationInterval: TimeInterval = 30

  fileprivate static var live: Self {

    func getString() -> String? {
      UIPasteboard.general.string
    }

    func put(
      string: String?
    ) {
      UIPasteboard.general.string = string
    }

    func putWithAutoExpiration(
      string: String?
    ) {
      guard let string = string else {
        // If the string is nil, we clear the pasteboard.
        UIPasteboard.general.string = nil
        return
      }
      let pasteboard: UIPasteboard = .general
      let provider: NSItemProvider = .init(object: string as NSString)
      pasteboard.setItemProviders(
        [
          provider
        ],
        localOnly: true,
        expirationDate: Date().addingTimeInterval(Self.expirationInterval)
      )
    }

    return .init(
      get: getString,
      put: put(string:),
      putWithAutoExpiration: putWithAutoExpiration(string:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSPasteboard() {
    self.use(
      OSPasteboard.live
    )
  }
}
