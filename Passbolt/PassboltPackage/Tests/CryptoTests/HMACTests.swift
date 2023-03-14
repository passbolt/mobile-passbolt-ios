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
import TestExtensions
import XCTest

@testable import Crypto

// test data based on https://www.rfc-editor.org/rfc/rfc4226
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class HMACTests: XCTestCase {

  var hmac: HMAC!

  override func setUp() {
    super.setUp()
    hmac = .commonCrypto
  }

  override func tearDown() {
    hmac = nil
    super.tearDown()
  }

  func test_sha1() {
    let secretData: Data = "12345678901234567890".data(using: .ascii)!
    XCTAssertEqual(
      self.hmac
        .sha1(
          secretData,
          counterData(for: 0)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "cc93cf18508d94934c64b65d8ba7667fb7cde4b0"
    )
    XCTAssertEqual(
      self.hmac
        .sha1(
          secretData,
          counterData(for: 1)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "75a48a19d4cbe100644e8ac1397eea747a2d33ab"
    )
    XCTAssertEqual(
      self.hmac
        .sha1(
          secretData,
          counterData(for: 2)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "0bacb7fa082fef30782211938bc1c5e70416ff44"
    )
    XCTAssertEqual(
      self.hmac
        .sha1(
          secretData,
          counterData(for: 3)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "66c28227d03a2d5529262ff016a1e6ef76557ece"
    )
    XCTAssertEqual(
      self.hmac
        .sha1(
          secretData,
          counterData(for: 4)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "a904c900a64b35909874b33e61c5938a8e15ed1c"
    )
  }

  func test_sha256() {
    let secretData: Data = "12345678901234567890".data(using: .ascii)!
    XCTAssertEqual(
      self.hmac
        .sha256(
          secretData,
          counterData(for: 0)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "4ab98dfbb333a33b157bac175c7534076b8184cbdc5943799c94173d9467bcf9"
    )
    XCTAssertEqual(
      self.hmac
        .sha256(
          secretData,
          counterData(for: 1)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "ec9d4f687b4efe6acc52100672660b84c0e7210ba0382141f8ecb90796cab912"
    )
    XCTAssertEqual(
      self.hmac
        .sha256(
          secretData,
          counterData(for: 2)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "ecc81319c35668cc4ee946e8c1e61b79c4d666b0d8faa9713b255a5c53a91a99"
    )
    XCTAssertEqual(
      self.hmac
        .sha256(
          secretData,
          counterData(for: 3)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "05705427c92ed061bcdeee471ba7e8b2feb47d1fc2d6f7a3e8e5ab707e3c6003"
    )
    XCTAssertEqual(
      self.hmac
        .sha256(
          secretData,
          counterData(for: 4)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "e96fc07b98bfeda152a2900970a7e0e2dd6c16b5f546d3ad19383aa845523e5e"
    )
  }

  func test_sha512() {
    let secretData: Data = "12345678901234567890".data(using: .ascii)!
    XCTAssertEqual(
      self.hmac
        .sha512(
          secretData,
          counterData(for: 0)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "c5a40237ed6bb8ad27f838f508359635e63e04bed229d847d1632691b64a8edb38e598817e3c9e6080b1709c6e94390bbab3120bccfa9bd524082aef98d24ac1"
    )
    XCTAssertEqual(
      self.hmac
        .sha512(
          secretData,
          counterData(for: 1)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "68a0d9fc7f6bc8e3060a4ca7999603b6c35d4af7b29e18c54f4f918c2440b47b6d8e2b2b46df25f1243068a9262d81c8879e07d54991a5ec783db7384b0b910d"
    )
    XCTAssertEqual(
      self.hmac
        .sha512(
          secretData,
          counterData(for: 2)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "dcf7a809c9b69f9d99ce38c493a9ff5e9e8a8c5a24623bb383852ac754a2c50238316bde98e204583ffa1ef035d9792614e6b53b58798cbb54f932a47d204c42"
    )
    XCTAssertEqual(
      self.hmac
        .sha512(
          secretData,
          counterData(for: 3)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "7a7c48cf2513a2332b2634ac6e31d2f49ac8fd3012e36af7cfd3542ec1d807c2ecf77c8aff2903433cb02801f3a5bfc27708f55f595144250088034d269e1fc6"
    )
    XCTAssertEqual(
      self.hmac
        .sha512(
          secretData,
          counterData(for: 4)
        )
        .map { String(format: "%02hhx", $0) }
        .joined(),
      "9ef13110496ce12ede4a7366cc9d81f44de8c990db7e1d47b6f74765b69dc63ccd5d86719818b3eee78e6863f2715129861d5bf4058a5c91e1dc59723d936c98"
    )
  }
}

func counterData(
  for counter: UInt64
) -> Data {
  var counter: UInt64 = counter.bigEndian
  return Data(
    bytes: &counter,
    count:
      MemoryLayout
      .size(ofValue: counter)
  )
}
