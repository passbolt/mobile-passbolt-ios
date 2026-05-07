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

public struct OSLinkOpener: Sendable {

  public var openURL: @Sendable (URLString) async throws -> Void
  public var openApplicationSettings: @Sendable () async throws -> Void
  public var openSystemSettings: @Sendable () async throws -> Void
}

extension OSLinkOpener: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      openURL: unimplemented1(),
      openApplicationSettings: unimplemented0(),
      openSystemSettings: unimplemented0()
    )
  }
  #endif
}

extension OSLinkOpener {

  // Legacy implementation
  fileprivate static var live: Self {

    @Sendable @MainActor func open(_ url: URL) async throws {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        UIApplication.shared.open(
          url,
          completionHandler: { success in
            if success {
              continuation.resume()
            }
            else {
              continuation
                .resume(
                  throwing:
                    URLOpeningFailed
                    .error()
                )
            }
          }
        )
      }
    }

    @Sendable func open(
      url urlString: URLString
    ) async throws {
      guard let preparedURL: URL = urlString.asURL()
      else {
        throw URLInvalid.error(rawString: urlString.rawValue)
      }
      guard await UIApplication.shared.canOpenURL(preparedURL)
      else {
        throw URLOpeningFailed.error()
      }
      try await open(preparedURL)
    }

    return Self(
      openURL: open(url:),
      openApplicationSettings: {
        try await open(
          url: .init(
            rawValue: UIApplication
              .openSettingsURLString
          )
        )
      },
      openSystemSettings: {
        try await open(url: "App-prefs:")
      }
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSLinkOpener() {
    self.use(
      OSLinkOpener.live
    )
  }
}

extension URLString {

  fileprivate func asURL() -> URL? {
    var value: String = self.rawValue
    // Add default https scheme if no scheme is present
    if URLComponents(string: value)?.scheme == nil {
      value = "https://" + value
    }
    return URL(string: value)
  }
}
