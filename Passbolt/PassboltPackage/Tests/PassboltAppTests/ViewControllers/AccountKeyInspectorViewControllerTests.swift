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

import FeatureScopes
import TestExtensions

@testable import Display
@testable import PassboltApp

final class AccountKeyInspectorViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(
      AccountScope.self,
      context: .mock_ada
    )
    set(SettingsScope.self)
    patch(
      \AccountDetails.updates,
      with: Variable(initial: Void())
        .asAnyUpdatable()
    )
    patch(
      \OSCalendar.format,
      with: always("DATE")
    )
    patch(
      \AccountDetails.avatarImage,
      with: always(.none)
    )
  }

  func test_viewState_loadsFromAccountDetails() async {
    patch(
      \AccountDetails.profile,
      with: always(.mock_ada)
    )
    patch(
      \AccountDetails.keyDetails,
      with: always(.mock_ada)
    )

    await withInstance(
      of: AccountKeyInspectorViewController.self,
      returns: AccountKeyInspectorViewController.State(
        avatarImage: .none,
        name: "Ada Lovelance",
        userID: "mock_ada",
        fingerprint: "MOCK _ADA",
        crationDate: "DATE",
        expirationDate: .none,
        keySize: "0",
        algorithm: "mock"
      )
    ) { feature in
      await feature.viewState.current
    }
  }
}
