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

@MainActor
final class ViewResourceDetailsTests: UITestCase {
  /// Test cases from https://passbolt.testrail.io/index.php?/cases/view/2444

  func test_onResourceDetailsView_UserCanRevealAndHidePassword_ofSimplePassword() async throws {
    try await execute(for: .simplePasswordV4)
  }

  func test_onResourceDetailsView_UserCanRevealAndHidePassword_ofPasswordWithDescription() async throws {
    try await execute(for: .passwordWithDescriptionV4)
  }

  func test_onResourceDetailsView_UserCanRevealAndHidePassword_ofSimplePasswordDeprecated() async throws {
    try await execute(for: .simplePasswordDeprecated)
  }

  func test_onResourceDetailsView_UserCanRevealAndHidePassword_ofDefaultResourceType() async throws {
    try await execute(for: .defaultResourceType)
  }

  private func execute(for resource: ResourceTestData, file: StaticString = #file, line: UInt = #line) async throws {
    await executeSteps("Verify resource details") {
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Group("Verify resource data") {
          VerifyEqual(screen.title.label, resource.resourceName, "Title")
          VerifyEqual(screen.usernameValue.label, resource.username, "Username")
          VerifyEqual(screen.mainURIValue.label, resource.mainURI, "Main URI")
        }

        Group("Verify password encryption") {
          Verify(screen.encryptedPasswordValue.label == "••••••••", "Password encrypted")
          Tap(screen.revealPasswordButton, "Reveal password")
          WaitFor(screen.revealedPasswordValue, timeout: .standardUI, "Password revealed")
          VerifyEqual(screen.revealedPasswordValue.label, resource.password, "Password")
        }
        .repeat(
          maxIterations: 3 // sometimes that fails with first runs
        )

        Group("Hide password") {
          Tap(screen.hidePasswordButton, "Hide password")
          Verify(screen.encryptedPasswordValue.exists, "Password hidden")
          Verify(screen.encryptedPasswordValue.label == "••••••••", "Shows encrypted dots")
        }
      }
    }
  }
}
