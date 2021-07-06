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

import Commons

import class Foundation.UserDefaults

//import Foundation

public struct MDMConfig: EnvironmentElement {

  public var loadConfig: () -> Dictionary<String, Any>
  public var updateConfig: (Dictionary<String, Any>) -> Void
}

extension MDMConfig {

  // user defaults key for MDM configuration
  private static let configurationKey: String = "com.apple.configuration.managed"

  public static var live: Self {
    let defaults: UserDefaults = .standard

    func loadConfig() -> Dictionary<String, Any> {
      defaults.object(
        forKey: MDMConfig.configurationKey
      ) as? [String: Any] ?? [:]
    }

    func updateConfig(_ updated: Dictionary<String, Any>) {
      defaults.set(
        updated,
        forKey: MDMConfig.configurationKey
      )
    }

    return Self(
      loadConfig: loadConfig,
      updateConfig: updateConfig
    )
  }
}

extension Environment {

  public var mdmConfig: MDMConfig {
    get { element(MDMConfig.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension MDMConfig {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      loadConfig: Commons.placeholder("You have to provide mocks for used methods"),
      updateConfig: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
