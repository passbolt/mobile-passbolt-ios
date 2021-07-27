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

import struct Foundation.Data

internal struct AccountTransferScanningPart {

  internal let version: String
  internal let page: Int
  internal let payload: Data
}

extension AccountTransferScanningPart {

  internal static func from(
    qrCode string: String
  ) -> Result<Self, TheError> {
    var payloadPart: String = string
    let version: String = String(payloadPart.removeFirst())

    guard version == "1"
    else {
      return .failure(
        .accountTransferScanningRecoverableError(
          context: "part-decoding-invalid-version-or-code"
        )
        .appending(
          logMessage: "Invalid QRCode or version"
        )
      )
    }

    // Constructing page number from two first bytes of payload.
    let pageString: String = String([payloadPart.removeFirst(), payloadPart.removeFirst()])
    guard let page: Int = Int(pageString, radix: 16)
    else {
      return .failure(
        .accountTransferScanningError(
          context: "part-decoding-invalid-page"
        )
        .appending(
          logMessage: "Invalid QRCode data page"
        )
      )
    }

    guard let payloadData = payloadPart.data(using: .utf8)
    else {
      return .failure(
        .accountTransferScanningError(
          context: "part-decoding-invalid-encoding"
        )
        .appending(
          logMessage: "Invalid QRCode data encoding"
        )
      )
    }

    return .success(
      Self(
        version: version,
        page: page,
        payload: payloadData
      )
    )
  }
}
