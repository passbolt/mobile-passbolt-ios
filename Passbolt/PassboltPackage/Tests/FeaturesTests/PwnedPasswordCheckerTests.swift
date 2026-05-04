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

import TestExtensions

@testable import Features
@testable import Shared

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class PwnedPasswordCheckerTests: LoadableFeatureTestCase<PwnedPasswordChecker> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePwnedPasswordChecker()
  }

  override func prepare() throws {
    self.patch(
      \PwnedPasswordCheckNetworkOperation.execute,
      with: { _ in "" }
    )
  }

  // MARK: - Tests

  // SHA1("password") = "5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8"
  // prefix = "5BAA6", suffix = "1E4C9B93F3F0682250B6CF8331B7EE68FD8"

  func test_check_returnsFalse_whenSuffixFoundInResponse() async throws {
    let receivedPrefix: CriticalState<String?> = .init(nil)
    self.patch(
      \PwnedPasswordCheckNetworkOperation.execute,
      with: { prefix in
        receivedPrefix.set(prefix)
        return "0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n"
          + "1E4C9B93F3F0682250B6CF8331B7EE68FD8:3861493\r\n"
          + "00A8DAE4228F95A116BCA6B2C3834E03F30:2\r\n"
      }
    )

    let checker: PwnedPasswordChecker = try testedInstance()
    let result: Bool = try await checker.check("password")

    XCTAssertFalse(result)
    XCTAssertEqual(receivedPrefix.get(), "5BAA6")
  }

  func test_check_returnsTrue_whenSuffixNotInResponse() async throws {
    self.patch(
      \PwnedPasswordCheckNetworkOperation.execute,
      with: { _ in
        "0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n"
          + "00A8DAE4228F95A116BCA6B2C3834E03F30:2\r\n"
      }
    )

    let checker: PwnedPasswordChecker = try testedInstance()
    let result: Bool = try await checker.check("password")

    XCTAssertTrue(result)
  }

  func test_check_returnsTrue_whenResponseIsEmpty() async throws {
    self.patch(
      \PwnedPasswordCheckNetworkOperation.execute,
      with: { _ in "" }
    )

    let checker: PwnedPasswordChecker = try testedInstance()
    let result: Bool = try await checker.check("password")

    XCTAssertTrue(result)
  }

  func test_check_propagatesError_whenNetworkOperationThrows() async throws {
    self.patch(
      \PwnedPasswordCheckNetworkOperation.execute,
      with: { _ in
        throw MockError()
      }
    )

    let checker: PwnedPasswordChecker = try testedInstance()

    do {
      _ = try await checker.check("password")
      XCTFail("Expected error to be thrown")
    }
    catch is MockError {
      // expected
    }
    catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }
}

// MARK: - Test Helpers

private struct MockError: Error {}
