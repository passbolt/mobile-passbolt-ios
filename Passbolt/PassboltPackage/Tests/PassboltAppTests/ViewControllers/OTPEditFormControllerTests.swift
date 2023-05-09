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

@testable import PassboltApp

final class OTPEditFormControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.useLiveTOTPEditFormController() },
      for: TOTPEditFormController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(
      ResourceEditScope.self,
      context: .create(
        .totp,
        folderID: .none,
        uri: .none
      )
    )
  }

  func test_viewState_loadsFromFormState_initially() async throws {
    var resource: Resource = .init(
      type: .mock_totp
    )
    try resource
      .set(
        .string("name"),
        for: ResourceField.valuePath(forName: "name")
      )
    try resource
      .set(
        .totp(
          .init(
            sharedSecret: "SECRET",
            algorithm: .sha256,
            digits: 7,
            period: 32
          )
        ),
        for: ResourceField.valuePath(forName: "totp")
      )
    let mutableState: MutableState<Resource> = .init(initial: resource)
    patch(
      \ResourceEditForm.state,
      with: .init(viewing: mutableState)
    )
    patch(
      \ResourceEditForm.updatableTOTPField,
      with: always(
        .init(
          fieldPath: ResourceField.valuePath(forName: "totp"),
          access: { (access) throws in
            try await mutableState.update { state in
              try access(&state)
              return state
            }
          }
        )
      )
    )

    let feature: TOTPEditFormController = try self.testedInstance(context: .none)

    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: TOTPEditFormController.ViewState(
        nameField: .valid("name"),
        uriField: .valid(""),
        secretField: .valid("SECRET"),
        snackBarMessage: .none
      )
    ) {
      feature.viewState.value
    }
  }
}
