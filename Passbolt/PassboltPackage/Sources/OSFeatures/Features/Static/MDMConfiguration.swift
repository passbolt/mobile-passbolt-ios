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

import CommonModels

import class Foundation.UserDefaults

public struct MDMConfiguration {

  public var clear: @Sendable () -> Void
  public var preconfiguredAccounts: @Sendable () -> Array<TransferedAccount>
}

extension MDMConfiguration: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      clear: unimplemented(),
      preconfiguredAccounts: unimplemented()
    )
  }
  #endif
}

extension MDMConfiguration {

  // user defaults key for MDM configuration
  private static let configurationKey: String = "com.apple.configuration.managed"
  private static let configurationAccountsKey: String = "accounts"

  fileprivate static var live: Self {
    let defaults: UserDefaults = .standard

    @Sendable func configuration() -> Dictionary<String, Any> {
      defaults
        .object(
          forKey: MDMConfiguration.configurationKey
        )
        as? Dictionary<String, Any>
        ?? .init()
    }

    @Sendable func clear() {
      defaults
        .removeObject(
          forKey: MDMConfiguration.configurationKey
        )
    }

    @Sendable func preconfiguredAccounts() -> Array<TransferedAccount> {
      let configuration: Dictionary<String, Any> = configuration()
      let accountsConfiguration: Array<Dictionary<String, Any>> =
        configuration[MDMConfiguration.configurationAccountsKey]
        as? Array<Dictionary<String, Any>> ?? .init()

      let accounts: Array<TransferedAccount> =
        accountsConfiguration
        .compactMap { (configuration: Dictionary<String, Any>) -> TransferedAccount? in
          guard
            let userID: String = configuration["userID"] as? String,
            let domain: String = configuration["domain"] as? String,
            let username: String = configuration["username"] as? String,
            let firstName: String = configuration["firstName"] as? String,
            let lastName: String = configuration["lastName"] as? String,
            let avatarImageURL: URLString = (configuration["avatarImageURL"] as? String).map(
              URLString.init(rawValue:)
            ),
            let fingerprint: String = configuration["fingerprint"] as? String,
            let flattenedArmoredKey: String = configuration["armoredKey"] as? String
          else { return nil }
          // user defaults replacement through launch arguments cannot handle "-" and newlines
          // we have to recreate those manually and put the private key without
          // "-----BEGIN PGP PRIVATE KEY BLOCK-----" prefix and
          // "-----END PGP PRIVATE KEY BLOCK-----" suffix
          // additionally we have to replace all newlines (actaully \r\n) with \n explicitly
          // in order to recreate those here
          let armoredKey: String =
            "-----BEGIN PGP PRIVATE KEY BLOCK-----"
            + flattenedArmoredKey.replacingOccurrences(of: "\\n", with: "\r\n")
            + "-----END PGP PRIVATE KEY BLOCK-----"
          return TransferedAccount(
            userID: .init(rawValue: userID),
            domain: .init(rawValue: domain),
            username: username,
            firstName: firstName,
            lastName: lastName,
            avatarImageURL: avatarImageURL,
            fingerprint: .init(rawValue: fingerprint),
            armoredKey: .init(rawValue: armoredKey)
          )
        }

      return accounts
    }

    return .init(
      clear: clear,
      preconfiguredAccounts: preconfiguredAccounts
    )
  }
}

extension FeatureFactory {

  internal func useMDMConfiguration() {
    self.use(
      MDMConfiguration.live
    )
  }
}
