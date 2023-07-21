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
import FeatureScopes
import Features
import TestExtensions

@testable import PassboltUsers

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class UsersTests: LoadableFeatureTestCase<Users> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltUsers()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    use(UserDetailsFetchDatabaseOperation.placeholder)
    use(UsersListFetchDatabaseOperation.placeholder)
  }

  func test_userDetails_throws_whenUserDetailsThrows() async throws {
    patch(
      \UserDetails.details,
      context: .mock_1,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: Users = try testedInstance()

    var result: Error?
    do {
      _ = try await feature.userDetails(.mock_1)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_userDetails_returnsDetails_fromDetailsFeature() async throws {
    let expectedResult: UserDetailsDSV = .mock_1
    patch(
      \UserDetails.details,
      context: .mock_1,
      with: always(expectedResult)
    )

    let feature: Users = try testedInstance()

    var result: UserDetailsDSV?
    do {
      result = try await feature.userDetails(.mock_1)
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertEqual(result, expectedResult)
  }
}
