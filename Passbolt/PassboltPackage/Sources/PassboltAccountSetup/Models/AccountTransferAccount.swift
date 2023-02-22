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

import Accounts
import CommonModels
import Crypto
import CryptoKit

import struct Foundation.Data
import class Foundation.JSONDecoder

internal struct AccountTransferAccount {

  internal var userID: User.ID
  internal var fingerprint: Fingerprint
  internal var armoredKey: ArmoredPGPPrivateKey
}

extension AccountTransferAccount {

  internal static func from(
    _ parts: Array<AccountTransferScanningPart>,
    verificationHash: String
  ) -> Result<Self, Error> {
    let joinedDataParts: Data = Data(parts.map(\.payload).joined())
    let computedHash: String =
      SHA512
      .hash(data: joinedDataParts)
      .compactMap { String(format: "%02x", $0) }
      .joined()
    guard verificationHash == computedHash
    else {
      return .failure(
        AccountTransferScanningFailure.error()
          .pushing(.message("Data validation fail - invalid account data hash"))
      )
    }
    let jsonDecoder: JSONDecoder = .init()
    do {
      return .success(
        try jsonDecoder
          .decode(
            Self.self,
            from: joinedDataParts
          )
      )
    }
    catch {
      return .failure(
        AccountTransferScanningFailure.error()
          .pushing(.message("Invalid QRCode data - not a valid configuration json"))
      )
    }
  }
}

extension AccountTransferAccount: Codable {

  internal enum CodingKeys: String, CodingKey {

    case userID = "user_id"
    case fingerprint = "fingerprint"
    case armoredKey = "armored_key"
  }
}
