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

final class OTPResourcesListControllerTests: LoadableFeatureTestCase<OTPResourcesListController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveOTPResourcesListController()
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
      \AccountDetails.avatarImage,
       context: .mock_ada,
       with: always(nil)
    )
    patch(
      \OTPCodesController.dispose,
       with: always(Void())
    )
  }

  func test_refreshList_presentsErrorMessage_whenRefreshFails() {
    patch(
      \OTPResources.refreshIfNeeded,
       with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.error("testLocalizationKey")
    ) { feature in
      await feature.refreshList()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_showCentextualMenu_navigatesToOTPContextualMenu() {
    patch(
      \NavigationToOTPContextualMenu.mockPerform,
       with: { (_: Bool, context: OTPContextualMenuController.Context) async throws in
         self.executed(using: context.resourceID)
       }
    )
    withTestedInstanceExecuted(
      using: Resource.ID.mock_1
    ) { feature in
      feature.showCentextualMenu(.mock_1)
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_showAccountMenu_navigatesToAccountMenu() {
    patch(
      \NavigationToAccountMenu.mockPerform,
       with: always(self.executed())
    )
    withTestedInstanceExecuted() { feature in
      feature.showAccountMenu()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_createOTP_navigatesToOTPCreationMenu() {
    #warning("[MOB-1130] - menu skipped")
    return
    withTestedInstance { feature in
      feature.createOTP()
    }
  }

  func test_revealAndCopyOTP_presentsErrorMessage_whenAccessingOTPFails() {
    patch(
      \OTPCodesController.requestNextFor,
       with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.error("testLocalizationKey")
    ) { feature in
      feature.revealAndCopyOTP(.mock_1)
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_revealAndCopyOTP_presentsErrorMessage_whenCopyingOTPFails() {
    patch(
      \OTPCodesController.requestNextFor,
       with: always(
        .totp(
          .init(
            resourceID: .mock_1,
            otp: "123456",
            timeLeft: 20,
            period: 30
          )
        )
       )
    )
    patch(
      \OTPCodesController.copyFor,
       with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.error("testLocalizationKey")
    ) { feature in
      feature.revealAndCopyOTP(.mock_1)
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_revealAndCopyOTP_showsMessage_whenCopyingOTPSucceeds() {
    patch(
      \OTPCodesController.requestNextFor,
       with: always(
        .totp(
          .init(
            resourceID: .mock_1,
            otp: "123456",
            timeLeft: 20,
            period: 30
          )
        )
       )
    )
    patch(
      \OTPCodesController.copyFor,
       with: always(Void())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.info("otp.value.copied.message")
    ) { feature in
      feature.revealAndCopyOTP(.mock_1)
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_revealAndCopyOTP_requestsOTPValueForRequestedResource() {
    patch(
      \OTPCodesController.requestNextFor,
       with: always(
        .totp(
          .init(
            resourceID: .mock_1,
            otp: "123456",
            timeLeft: 20,
            period: 30
          )
        )
      )
    )
    patch(
      \OTPCodesController.copyFor,
       with: { (resourceID: Resource.ID) async throws in
         self.executed(using: resourceID)
       }
    )
    withTestedInstanceExecuted(
      using: Resource.ID.mock_1
    ) { feature in
      feature.revealAndCopyOTP(.mock_1)
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_revealAndCopyOTP_showsOTPValue_whenRevealOTPSucceeds() {
    let resourceUpdates: UpdatesSequenceSource = .init()
    patch(
      \OTPResources.updates,
       with: resourceUpdates.updatesSequence
    )
    let otpUpdates: UpdatesSequenceSource = .init()
    patch(
      \OTPCodesController.updates,
       with: otpUpdates.updatesSequence
    )
    patch(
      \OTPCodesController.current,
       with: always(
        .totp(
          .init(
            resourceID: .mock_1,
            otp: "123456",
            timeLeft: 20,
            period: 30
          )
        )
       )
    )
    patch(
      \OTPCodesController.requestNextFor,
       with: always(
        .totp(
          .init(
            resourceID: .mock_1,
            otp: "123456",
            timeLeft: 20,
            period: 30
          )
        )
       )
    )
    patch(
      \OTPCodesController.copyFor,
       with: always(Void())
    )
    patch(
      \OTPResources.filteredList,
       with: always(
        [
          .init(
            id: .mock_1,
            parentFolderID: .none,
            name: "OTP",
            username: .none,
            url: .none
          )
        ]
       )
    )
    withTestedInstanceReturnsEqual(
      true,
      timeout: 10
    ) { feature in
      Task {
        await self.mockExecutionControl.executeAll()
      }
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      feature.revealAndCopyOTP(.mock_1)
      otpUpdates.sendUpdate()
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      return await feature.viewState.otpResources.contains(where: { $0.totpValue != .none })
    }
  }

  func test_hideOTPCodes_disposesOTPValues() {
    patch(
      \OTPCodesController.dispose,
       with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.hideOTPCodes()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_initialization_loadsListOfResources() {
    let resourceUpdates: UpdatesSequenceSource = .init()
    patch(
      \OTPResources.updates,
       with: resourceUpdates.updatesSequence
    )
    patch(
      \OTPResources.filteredList,
       with: always(
        [
          .init(
            id: .mock_1,
            parentFolderID: .none,
            name: "OTP",
            username: .none,
            url: .none
          )
        ]
       )
    )
    withTestedInstanceReturnsEqual(
      [
        .init(
          id: .mock_1,
          name: "OTP"
        )
      ] as Array<TOTPResourceViewModel>,
      timeout: 3
    ) { feature in
      Task {
        await self.mockExecutionControl.executeAll()
      }
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      resourceUpdates.endUpdates()
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      return await feature.viewState.otpResources
    }
  }
}

