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
import NetworkOperations

import struct Foundation.Data

/// Checks whether a password has been found in known data breaches
/// using the Have I Been Pwned Pwned Passwords API (k-anonymity model).
internal struct PwnedPasswordChecker: Sendable {

  /// Returns `true` if the password has been found in known data breaches.
  internal var check: @Sendable (String) async throws -> Bool
}

extension PwnedPasswordChecker: LoadableFeature {

  #if DEBUG
  nonisolated internal static var placeholder: PwnedPasswordChecker {
    .init(
      check: unimplemented1()
    )
  }
  #endif

  @MainActor internal static func load(
    using features: Features
  ) throws -> Self {
    let pwnedPasswordCheck: PwnedPasswordCheckNetworkOperation = try features.instance()

    @Sendable func check(password: String) async throws -> Bool {
      let hashHex: String = sha1Hex(password)
      let prefix: String = .init(hashHex.prefix(5))
      let suffix: String = .init(hashHex.dropFirst(5))

      let responseBody: String = try await pwnedPasswordCheck(prefix)

      let lines: Array<Substring> = responseBody.split(separator: "\r\n")
      for line in lines {
        if let lineSuffix: Substring = line.split(separator: ":").first, lineSuffix == suffix {
          return false
        }
      }

      return true
    }

    return Self(
      check: check(password:)
    )
  }
}

// MARK: - SHA-1 Hashing

extension PwnedPasswordChecker {

  fileprivate static func sha1Hex(_ input: String) -> String {
    let data: Data = .init(input.utf8)
    var digest: Array<UInt8> = .init(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
      _ = CC_SHA1(pointer.baseAddress, CC_LONG(data.count), &digest)
    }
    return digest.map { String(format: "%02X", $0) }.joined()
  }
}

// MARK: - Error

extension PwnedPasswordChecker {

  internal struct CheckError: TheError {

    internal static func error(
      file: StaticString = #fileID,
      line: UInt = #line
    ) -> Self {
      Self(
        context: .context(
          .message(
            "Failed to check password against pwned database",
            file: file,
            line: line
          )
        )
      )
    }

    public var context: DiagnosticsContext
  }
}

// MARK: - Registration

extension FeaturesRegistry {

  internal mutating func usePwnedPasswordChecker() {
    self.use(
      .lazyLoaded(
        PwnedPasswordChecker.self,
        load: PwnedPasswordChecker.load(using:)
      )
    )
  }
}
