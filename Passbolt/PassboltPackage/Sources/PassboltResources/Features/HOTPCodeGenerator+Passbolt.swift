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

import Crypto
import Resources

import struct Foundation.Data

// MARK: - Implementation

extension HOTPCodeGenerator {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let hmac: HMAC = features.instance()

    let computeHash: (_ key: Data, _ value: Data) -> Data
    switch context.algorithm {
    case .sha1:
      computeHash = hmac.sha1

    case .sha256:
      computeHash = hmac.sha256

    case .sha512:
      computeHash = hmac.sha512
    }

    let secretData: Data =
      .init(base32Encoded: context.sharedSecret)
      ?? context
      .sharedSecret
      .data(using: .utf8)
      ?? .init()

    let digits: Int32 = Int32(context.digits)
    let digitsMultiplier: Int32 = {
      var result: Int32 = 1
      for _ in 0..<digits {
        result *= 10
      }
      return result
    }()

    @Sendable nonisolated func generate(
      using counter: UInt64
    ) -> HOTPValue {
      let counterData: Data = withUnsafeBytes(
        of: counter.bigEndian
      ) { (bytes: UnsafeRawBufferPointer) in
        Data(bytes)
      }

      let hash: Data = computeHash(secretData, counterData)
      let offset: Int = (hash.last.map(Int.init) ?? 0) & 0x0f

      var rawValue: Int32 = .init(littleEndian: 0)
      withUnsafeMutableBytes(
        of: &rawValue
      ) { (buffer: UnsafeMutableRawBufferPointer) in
        buffer[0] = hash[offset + 3]
        buffer[1] = hash[offset + 2]
        buffer[2] = hash[offset + 1]
        buffer[3] = hash[offset] & 0x7f
      }

      let rawOTP: Int32 = rawValue % digitsMultiplier

      var otpString: String = .init(rawOTP)
      while otpString.count < digits {
        otpString = "0" + otpString
      }

      return HOTPValue(
        resourceID: context.resourceID,
        otp: OTP(rawValue: otpString),
        counter: counter
      )
    }

    return .init(
      generate: generate(using:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltHOTPCodeGenerator() {
    self.use(
      .disposable(
        HOTPCodeGenerator.self,
        load: HOTPCodeGenerator.load(features:context:)
      )
    )
  }
}
