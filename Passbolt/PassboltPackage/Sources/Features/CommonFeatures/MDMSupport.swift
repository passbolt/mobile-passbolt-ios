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

import Environment

public struct MDMSupport {

  #if DEBUG  // disabled in prod for now, it might be enabled in future
  public var transferedAccount: () -> TransferedAccount?
  #endif
}

#if DEBUG  // disabled in prod for now, it might be enabled in future
extension MDMSupport {

  public struct TransferedAccount: Decodable {

    public let userID: String
    public let domain: String
    public let username: String
    public let firstName: String
    public let lastName: String
    public let avatarImageURL: String
    public let fingerprint: String
    public let armoredKey: String
  }
}
#endif

extension MDMSupport: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let mdmConfig: MDMConfig = environment.mdmConfig

    #if DEBUG
    func transferedAccount() -> TransferedAccount? {
      var config: Dictionary<String, Any> = mdmConfig.loadConfig()
      guard
        let transferedAccountData: Dictionary<String, Any> = config["transferedAccountData"] as? Dictionary<String, Any>
      else { return nil }
      // We are removing this part of data for security reason
      // - it will contain user private key (hopefully encrypted but still)
      // it shouldn't be stored
      config["transferedAccountData"] = nil
      mdmConfig.updateConfig(config)
      guard
        let userID: String = transferedAccountData["userID"] as? String,
        let domain: String = transferedAccountData["domain"] as? String,
        let username: String = transferedAccountData["username"] as? String,
        let firstName: String = transferedAccountData["firstName"] as? String,
        let lastName: String = transferedAccountData["lastName"] as? String,
        let avatarImageURL: String = transferedAccountData["avatarImageURL"] as? String,
        let fingerprint: String = transferedAccountData["fingerprint"] as? String,
        let flattenedArmoredKey: String = transferedAccountData["flattenedArmoredKey"] as? String
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
        userID: userID,
        domain: domain,
        username: username,
        firstName: firstName,
        lastName: lastName,
        avatarImageURL: avatarImageURL,
        fingerprint: fingerprint,
        armoredKey: armoredKey
      )
    }

    return Self(
      transferedAccount: transferedAccount
    )
    #else
    return Self()
    #endif
  }
}

#if DEBUG
extension MDMSupport {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      transferedAccount: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
