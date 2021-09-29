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
import Environment
import Foundation

public struct LinkOpener {

  public var openLink: (URL) -> AnyPublisher<Bool, Never>
  public var openApp: () -> AnyPublisher<Bool, Never>
  public var openAppSettings: () -> AnyPublisher<Bool, Never>
  public var openSystemSettings: () -> AnyPublisher<Bool, Never>
}

extension LinkOpener: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> LinkOpener {
    let externalURLOpener: ExternalURLOpener = environment.externalURLOpener

    return Self(
      openLink: externalURLOpener.openLink,
      openApp: externalURLOpener.openApp,
      openAppSettings: externalURLOpener.openAppSettings,
      openSystemSettings: externalURLOpener.openSystemSettings
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      openLink: Commons.placeholder("You have to provide mocks for used methods"),
      openApp: Commons.placeholder("You have to provide mocks for used methods"),
      openAppSettings: Commons.placeholder("You have to provide mocks for used methods"),
      openSystemSettings: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension TheError {

  public static func failedToOpenURL(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .failedToOpenURL,
      underlyingError: underlyingError,
      extensions: .init()
    )
  }
}

extension TheError.ID {

  public static let failedToOpenURL: Self = "failedToOpenURL"
}
