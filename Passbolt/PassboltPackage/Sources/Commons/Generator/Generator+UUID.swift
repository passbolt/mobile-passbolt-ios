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

import struct Foundation.UUID

#if DEBUG

extension UUID: RandomlyGenerated {

  // WARNING: this is not a proper UUID generation algorithm,
  // it is meant to be used as a placeholder or for generating mocks
  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: { (lower: UInt64, upper: UInt64) in
        var bytes: Array<UInt8> = .init()
        bytes.reserveCapacity(16)

        withUnsafeBytes(of: lower.bigEndian) { lowerBytes in
          bytes.append(contentsOf: lowerBytes)
        }
        withUnsafeBytes(of: upper.bigEndian) { upperBytes in
          bytes.append(contentsOf: upperBytes)
        }

        return UUID(
          uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
          )
        )
      },
      randomnessGenerator.map(\.rawValue),
      randomnessGenerator.map(\.rawValue)
    )
  }
}
#endif
