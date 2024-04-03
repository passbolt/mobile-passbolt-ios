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

public struct AccountKitDTO: Codable {

  public var privateKeyArmored: ArmoredPGPPrivateKey
  public var publicKeyArmored: ArmoredPGPPublicKey
  public var firstName: String
  public var lastname: String
  public var userID: Account.UserID
  public var domain: URLString
  public var username: String

  public init(
    privateKeyArmored: ArmoredPGPPrivateKey,
    publicKeyArmored: ArmoredPGPPublicKey,
    firstName: String,
    lastname: String,
    userID: Account.UserID,
    domain: URLString,
    username: String
  ) {
    self.privateKeyArmored = privateKeyArmored
    self.publicKeyArmored = publicKeyArmored
    self.firstName = firstName
    self.lastname = lastname
    self.userID = userID
    self.domain = domain
    self.username = username
  }
}

extension AccountKitDTO {
  private enum CodingKeys: String, CodingKey {
    case privateKeyArmored = "user_private_armored_key"
    case publicKeyArmored = "user_public_armored_key"
    case firstName = "first_name"
    case lastname = "last_name"  // Corrected to match the property name
    case userID = "user_id"
    case domain
    case username
  }
}
