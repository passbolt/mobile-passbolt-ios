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
import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SessionStateTests: LoadableFeatureTestCase<SessionState> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionState
  }

  override func prepare() throws {
    patch(
      \OSTime.timestamp,
      with: always(self.timestamp)
    )
    self.timestamp = 0 as Timestamp
  }

  func test_account_isNone_initially() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.account()
    }
  }

  func test_setAccount_setsAccount() {
    withTestedInstanceReturnsEqual(Account.mock_ada) { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      return await testedInstance.account()
    }
  }

  func test_setAccount_clearsAllData_whenSettingNone() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setPassphrase("passphrase")
      await testedInstance.setAccessToken(.valid)
      await testedInstance.setRefreshToken("refreshToken")
      await testedInstance.setMFAToken("mfaToken")
      await testedInstance.setAccount(.none)

      await XCTAssertValue(equal: .none) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
    }
  }

  func test_setAccount_clearsAllButAccount_whenSettingDifferentAccount() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setPassphrase("passphrase")
      await testedInstance.setAccessToken(.valid)
      await testedInstance.setRefreshToken("refreshToken")
      await testedInstance.setMFAToken("mfaToken")
      await testedInstance.setAccount(.mock_frances)

      await XCTAssertValue(equal: .mock_frances) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
    }
  }

  func test_passphrase_returnsSome_whenNotExpired() {
    withTestedInstanceReturnsEqual("passphrase" as Passphrase) { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setPassphrase("passphrase")
      return await testedInstance.passphrase()
    }
  }

  func test_passphrase_returnsNone_whenExpired() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setPassphrase("passphrase")
      self.timestamp = (5 * 60 * 60) as Timestamp
      return await testedInstance.passphrase()
    }
  }

  func test_accessToken_returnsSome_whenValid() {
    withTestedInstanceReturnsEqual(JWT.valid) { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setAccessToken(.valid)
      return await testedInstance.validAccessToken()
    }
  }

  func test_accessToken_returnsNone_whenExpired() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.setAccount(.mock_ada)
      await testedInstance.setAccessToken(.valid)
      self.timestamp = 2_000_000_000 as Timestamp
      return await testedInstance.validAccessToken()
    }
  }

  func test_refreshToken_returnsNone_whenAccessedMoreThanOnce() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.setRefreshToken("refreshToken")
      _ = await testedInstance.refreshToken()
      return await testedInstance.refreshToken()
    }
  }

  func test_setingValues_hasNoEffect_withoutAccount() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.setPassphrase("passphrase")
      await testedInstance.setAccessToken(.valid)
      await testedInstance.setRefreshToken("refreshToken")
      await testedInstance.setMFAToken("mfaToken")

      await XCTAssertValue(equal: .none) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
    }
  }
}
