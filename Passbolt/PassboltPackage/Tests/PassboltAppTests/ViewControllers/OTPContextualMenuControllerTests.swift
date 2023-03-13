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

final class OTPContextualMenuControllerTests: LoadableFeatureTestCase<OTPContextualMenuController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveOTPCContextualMenuController()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
		patch(
			\ResourceDetails.details,
			context: .mock_1,
			with: always(.mock_1)
		)
  }

  func test_dismiss_revertsNavigationToSelf() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(self.executed())
    )
    withTestedInstanceExecuted(
      context: .init(
        resourceID: .mock_1,
        showMessage: { _ in }
      )
    ) { feature in
      feature.dismiss()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_revertsNavigationToSelf_whenSucceeding() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(self.executed())
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \OTPResources.totpCodesFor,
      with: always(
        .init(
          resourceID: .mock_1,
          generate: { _ in
            .init(
              otp: "123456",
              timeLeft: 20,
              period: 30
            )
          }
        )
      )
    )
    withTestedInstanceExecuted(
      context: .init(
        resourceID: .mock_1,
        showMessage: { _ in }
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_revertsNavigationToSelf_whenFailing() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(self.executed())
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \OTPResources.totpCodesFor,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceExecuted(
      context: .init(
        resourceID: .mock_1,
        showMessage: { _ in }
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_showsMessage_whenCodeIsCopied() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(Void())
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \OTPResources.totpCodesFor,
      with: always(
        .init(
          resourceID: .mock_1,
          generate: { _ in
            .init(
              otp: "123456",
              timeLeft: 20,
              period: 30
            )
          }
        )
      )
    )
    withTestedInstanceExecuted(
      using: SnackBarMessage.info("otp.copied.message"),
      context: .init(
        resourceID: .mock_1,
        showMessage: self.executed(using:)
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_showsErrorMessage_whenCodeGenerationFails() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(Void())
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \OTPResources.totpCodesFor,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceExecuted(
      using: SnackBarMessage.error("testLocalizationKey"),
      context: .init(
        resourceID: .mock_1,
        showMessage: self.executed(using:)
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_doesNotModifyPasteboard_whenCodeGenerationFails() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(Void())
    )
    patch(
      \OSPasteboard.put,
      with: always(self.executed())
    )
    patch(
      \OTPResources.totpCodesFor,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceNotExecuted(
      context: .init(
        resourceID: .mock_1,
        showMessage: { _ in }
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_copyCode_putsCodeIntoPasteboard_whenCodeGenerationSucceeds() {
    patch(
      \NavigationToOTPContextualMenu.mockRevert,
      with: always(Void())
    )
    patch(
      \OSPasteboard.put,
      with: self.executed(using:)
    )
    patch(
      \OTPResources.totpCodesFor,
      with: always(
        .init(
          resourceID: .mock_1,
          generate: { _ in
            .init(
              otp: "123456",
              timeLeft: 20,
              period: 30
            )
          }
        )
      )
    )
    withTestedInstanceExecuted(
      using: "123456",
      context: .init(
        resourceID: .mock_1,
        showMessage: { _ in }
      )
    ) { feature in
      feature.copyCode()
      await self.mockExecutionControl.executeAll()
    }
  }

	func test_viewState_updatesTitle_fromResourceDetails() {

		withTestedInstanceReturnsEqual(
			DisplayableString.raw("Mock_1"),
			context: .init(
				resourceID: .mock_1,
				showMessage: self.executed(using:)
			)
		) { feature in
			await self.mockExecutionControl.executeAll()
			return await feature.viewState.title
		}
	}
}
