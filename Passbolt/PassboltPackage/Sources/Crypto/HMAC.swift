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

import CommonCrypto
import Features

public struct HMAC {

  public var sha1: @Sendable (_ key: Data, _ data: Data) -> Data
  public var sha256: @Sendable (_ key: Data, _ data: Data) -> Data
  public var sha512: @Sendable (_ key: Data, _ data: Data) -> Data
}

extension HMAC: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      sha1: unimplemented2(),
      sha256: unimplemented2(),
      sha512: unimplemented2()
    )
  }
  #endif
}

extension HMAC {

  internal static var commonCrypto: Self {

    @Sendable func sha1(
      key: Data,
      data: Data
    ) -> Data {
      var result: Data = .init(
        repeating: 0,
        count: Int(CC_SHA1_DIGEST_LENGTH)
      )
      data.withUnsafeBytes { (dataPointer: UnsafeRawBufferPointer) in
        key.withUnsafeBytes { (keyPointer: UnsafeRawBufferPointer) in
          result.withUnsafeMutableBytes { (resultPointer: UnsafeMutableRawBufferPointer) in
            CCHmac(
              CCHmacAlgorithm(kCCHmacAlgSHA1),
              keyPointer.baseAddress,
              keyPointer.count,
              dataPointer.baseAddress,
              dataPointer.count,
              resultPointer.baseAddress
            )
          }
        }
      }

      return result
    }

    @Sendable func sha256(
      key: Data,
      data: Data
    ) -> Data {
      var result: Data = .init(
        repeating: 0,
        count: Int(CC_SHA256_DIGEST_LENGTH)
      )
      data.withUnsafeBytes { (dataPointer: UnsafeRawBufferPointer) in
        key.withUnsafeBytes { (keyPointer: UnsafeRawBufferPointer) in
          result.withUnsafeMutableBytes { (resultPointer: UnsafeMutableRawBufferPointer) in
            CCHmac(
              CCHmacAlgorithm(kCCHmacAlgSHA256),
              keyPointer.baseAddress,
              keyPointer.count,
              dataPointer.baseAddress,
              dataPointer.count,
              resultPointer.baseAddress
            )
          }
        }
      }

      return result
    }

    @Sendable func sha512(
      key: Data,
      data: Data
    ) -> Data {
      var result: Data = .init(
        repeating: 0,
        count: Int(CC_SHA512_DIGEST_LENGTH)
      )
      data.withUnsafeBytes { (dataPointer: UnsafeRawBufferPointer) in
        key.withUnsafeBytes { (keyPointer: UnsafeRawBufferPointer) in
          result.withUnsafeMutableBytes { (resultPointer: UnsafeMutableRawBufferPointer) in
            CCHmac(
              CCHmacAlgorithm(kCCHmacAlgSHA512),
              keyPointer.baseAddress,
              keyPointer.count,
              dataPointer.baseAddress,
              dataPointer.count,
              resultPointer.baseAddress
            )
          }
        }
      }

      return result
    }

    return .init(
      sha1: sha1(key:data:),
      sha256: sha256(key:data:),
      sha512: sha512(key:data:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useHMAC() {
    self.use(
      HMAC.commonCrypto
    )
  }
}
