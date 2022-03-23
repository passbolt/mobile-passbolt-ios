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

import struct Foundation.Data
import class Foundation.JSONDecoder
import struct Foundation.URLComponents

internal struct AccountTransferConfiguration {

  internal var transferID: String
  internal var pagesCount: Int
  internal var userID: String
  internal var authenticationToken: String
  internal var domain: URLString
  internal var hash: String
}

extension AccountTransferConfiguration {

  internal static func from(
    _ part: AccountTransferScanningPart
  ) -> Result<Self, Error> {
    let jsonDecoder: JSONDecoder = .init()
    var decoded: Self
    do {
      decoded =
        try jsonDecoder
        .decode(
          Self.self,
          from: part.payload
        )
    }
    catch {
      return .failure(
        TheErrorLegacy.accountTransferScanningError(context: "configuration-decoding-invalid-json")
          .appending(logMessage: "Invalid QRCode data - not a valid configuration json")
      )
    }

    if  // here we verify if it is valid url
    let urlComponents: URLComponents = .init(string: decoded.domain.rawValue),
      urlComponents.scheme == "https"  // we don't allow http servers since we can't handle it
    {
      return .success(decoded)
    }
    else {
      return .failure(
        TheErrorLegacy.accountTransferScanningError(context: "configuration-decoding-invalid-domain")
          .appending(logMessage: "Invalid QRCode data - not a valid configuration domain")
      )
    }
  }
}

extension AccountTransferConfiguration: Decodable {

  internal enum CodingKeys: String, CodingKey {

    case transferID = "transfer_id"
    case pagesCount = "total_pages"
    case userID = "user_id"
    case authenticationToken = "authentication_token"
    case domain = "domain"
    case hash = "hash"
  }
}
