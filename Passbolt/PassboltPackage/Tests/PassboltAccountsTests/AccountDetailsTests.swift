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

@testable import PassboltAccounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountDetailsTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      AccountScope.self,
      context: .mock_ada
    )
    register(
      { $0.usePassboltAccountDetails() },
      for: AccountDetails.self
    )
  }

  func test_avatarImage_returnsNone_whenLoadingProfileFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(returns: .none) { (feature: AccountDetails) in
      try await feature.avatarImage()
    }
  }

  func test_avatarImage_returnsNone_whenMediaDownloadFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )
    patch(
      \MediaDownloadNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(returns: .none) { (feature: AccountDetails) in
      try await feature.avatarImage()
    }
  }

  func test_avatarImage_returnsData_whenMediaDownloadSucceeds() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )
    patch(
      \MediaDownloadNetworkOperation.execute,
      with: always(Data([0x65, 0x66]))
    )

    await withInstance(returns: Data([0x65, 0x66])) { (feature: AccountDetails) in
      try await feature.avatarImage()
    }
  }

  func test_isPassphraseStored_returnsTrue_whenAccountDataStoresPassphrase() async {
    patch(
      \AccountsDataStore.isAccountPassphraseStored,
      with: always(true)
    )

    await withInstance(returns: true) { (feature: AccountDetails) in
      feature.isPassphraseStored()
    }
  }

  func test_isPassphraseStored_returnsFalse_whenAccountDataDoesNotStirePassphrase() async {
    patch(
      \AccountsDataStore.isAccountPassphraseStored,
      with: always(false)
    )

    await withInstance(returns: false) { (feature: AccountDetails) in
      feature.isPassphraseStored()
    }
  }

  func test_keyDetails_fails_whenFetchingDataFails() async {
    patch(
      \UserDetailsFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(throws: MockIssue.self) { (feature: AccountDetails) in
      try await feature.keyDetails()
    }
  }

  func test_keyDetails_succeeds_whenFetchingDataSucceeds() async {
    patch(
      \UserDetailsFetchNetworkOperation.execute,
      with: always(.mock_ada)
    )

    await withInstance(returns: .mock_ada) { (feature: AccountDetails) in
      try await feature.keyDetails()
    }
  }

  func test_profile_fails_whenLoadingProfileDataFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(throws: MockIssue.self) { (feature: AccountDetails) in
      try feature.profile()
    }
  }

  func test_profile_loadsStoredProfile() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )

    await withInstance(returns: .mock_ada) { (feature: AccountDetails) in
      try feature.profile()
    }
  }

  func test_updateProfile_throws_whenFetchingDataFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(throws: MockIssue.self) { (feature: AccountDetails) in
      try await feature.updateProfile()
    }
  }

  func test_updateProfile_throws_whenFetchingProfileUpdateFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )
    patch(
      \UserDetailsFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(throws: MockIssue.self) { (feature: AccountDetails) in
      try await feature.updateProfile()
    }
  }

  func test_updateProfile_throws_whenStoringProfileUpdateFails() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )
    patch(
      \UserDetailsFetchNetworkOperation.execute,
      with: always(.mock_ada)
    )
    patch(
      \AccountsDataStore.updateAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \AccountsDataStore.updateAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )

    await withInstance(throws: MockIssue.self) { (feature: AccountDetails) in
      try await feature.updateProfile()
    }
  }

  func test_updateProfile_succeeds_whenStoringProfileUpdateSucceeds() async {
    patch(
      \AccountsDataStore.loadAccountProfile,
      with: always(.mock_ada)
    )
    patch(
      \UserDetailsFetchNetworkOperation.execute,
      with: always(.mock_ada)
    )
    patch(
      \AccountsDataStore.updateAccountProfile,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \AccountsDataStore.updateAccountProfile,
      with: always(Void())
    )

    await withInstance { (feature: AccountDetails) in
      try await feature.updateProfile()
    }
  }
}
