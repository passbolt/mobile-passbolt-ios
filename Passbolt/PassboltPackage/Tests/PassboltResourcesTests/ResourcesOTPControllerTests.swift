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

@testable import PassboltResources

final class ResourcesOTPControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourcesOTPController() },
      for: ResourcesOTPController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \OSTime.timeVariable,
      with: always(Constant(Void()).asAnyUpdatable())
    )
    patch(
      \SessionData.lastUpdate,
      with: Constant(.zero).asAnyUpdatable()
    )
  }

  func test_currentOTP_neverReturns_withoutRevealedOTP() async throws {
    let tested: ResourcesOTPController = try self.testedInstance()
    await withSerialTaskExecutor {
      let task: Task<OTPValue?, Never> = .detached {
        try? await tested.currentOTP.value
      }
      await Task.yield()
      task.cancel()
      let value: OTPValue? = await task.value
      await verifyIfIsNone(value)
    }
  }

  func test_revealOTP_neverReturns_withFetchingSecretError() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourcesOTPController = try self.testedInstance()
    await withSerialTaskExecutor {
      let task: Task<OTPValue?, Never> = .detached {
        try? await tested.revealOTP(.mock_1)
      }
      await Task.yield()
      task.cancel()
      let value: OTPValue? = await task.value
      await verifyIfIsNone(value)
    }
  }

  func test_revealOTP_neverReturns_withResourceAccessError() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(.null)
    )
    patch(
      \ResourceController.state,
      with: Constant(MockIssue.error()).asAnyUpdatable()
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    await withSerialTaskExecutor {
      let task: Task<OTPValue?, Never> = .detached {
        try? await tested.revealOTP(.mock_1)
      }
      await Task.yield()
      task.cancel()
      let value: OTPValue? = await task.value
      await verifyIfIsNone(value)
    }
  }

  func test_revealOTP_neverReturns_withResourceSecretInvalidOrMissing() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_1).asAnyUpdatable()
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    await withSerialTaskExecutor {
      let task: Task<OTPValue?, Never> = .detached {
        try? await tested.revealOTP(.mock_1)
      }
      await Task.yield()
      task.cancel()
      let value: OTPValue? = await task.value
      await verifyIfIsNone(value)
    }
  }

  func test_revealOTP_returnsOTP_withValidResource() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_totp).asAnyUpdatable()
    )
    let expectedResult: TOTPValue =
      .init(
        resourceID: .mock_1,
        otp: "123",
        timeLeft: 20,
        period: 30
      )
    patch(
      \TOTPCodeGenerator.prepare,
      with: always(always(expectedResult))
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    try await withSerialTaskExecutor {
      await verifyIf(
        try await tested.revealOTP(.mock_1),
        isEqual: .totp(expectedResult)
      )
    }
  }

  func test_revealOTP_returnsUpdatedOTP_whenRequestedWithSameResourceID() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_totp).asAnyUpdatable()
    )
    self.totpValue = TOTPValue(
      resourceID: .mock_1,
      otp: "123",
      timeLeft: 20,
      period: 30
    )
    patch(
      \TOTPCodeGenerator.prepare,
      with: always(always(self.totpValue))
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    try await withSerialTaskExecutor {
      let initial: OTPValue = try await tested.revealOTP(.mock_1)
      await verifyIf(
        try await tested.currentOTP.value,
        isEqual: initial
      )
      self.totpValue = TOTPValue(
        resourceID: .mock_1,
        otp: "456",
        timeLeft: 10,
        period: 30
      )
      await verifyIf(
        try await tested.revealOTP(.mock_1),
        isNotEqual: initial
      )
      await verifyIf(
        try await tested.currentOTP.value,
        isNotEqual: initial
      )
    }
  }

  func test_revealOTP_updatesOTP_withUpdatedResourceID() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_totp).asAnyUpdatable()
    )
    self.totpValue = TOTPValue(
      resourceID: .mock_1,
      otp: "123",
      timeLeft: 20,
      period: 30
    )
    patch(
      \TOTPCodeGenerator.prepare,
      with: always(always(self.totpValue))
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    try await withSerialTaskExecutor {
      let initial: OTPValue = try await tested.revealOTP(.mock_1)
      await verifyIf(
        initial.resourceID,
        isEqual: .mock_1
      )
      self.totpValue = TOTPValue(
        resourceID: .mock_2,
        otp: "456",
        timeLeft: 10,
        period: 30
      )
      await verifyIf(
        try await tested.revealOTP(.mock_2),
        isNotEqual: initial
      )
      await verifyIf(
        try await tested.revealOTP(.mock_2).resourceID,
        isEqual: .mock_2
      )
    }
  }

  func test_revealOTP_returnsNewOTP_withTimeTicks() async throws {
    let timeTicks: Variable<Void> = .init(initial: Void())
    patch(
      \OSTime.timeVariable,
      with: always(timeTicks.asAnyUpdatable())
    )
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_totp).asAnyUpdatable()
    )
    self.totpValue = TOTPValue(
      resourceID: .mock_1,
      otp: "123",
      timeLeft: 20,
      period: 30
    )
    patch(
      \TOTPCodeGenerator.prepare,
      with: always(always(self.totpValue))
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    try await withSerialTaskExecutor {
      let initial: OTPValue = try await tested.revealOTP(.mock_1)
      await verifyIf(
        try await tested.currentOTP.value,
        isEqual: initial
      )
      self.totpValue = TOTPValue(
        resourceID: .mock_1,
        otp: "456",
        timeLeft: 10,
        period: 30
      )
      timeTicks.assign(Void())
      await verifyIf(
        try await tested.currentOTP.value,
        isEqual: .totp(self.totpValue)
      )
    }
  }

  func test_hideOTP_clearsOTP_whenOTPWasAvailable() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(Resource.mock_totp.secret)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_totp).asAnyUpdatable()
    )
    patch(
      \TOTPCodeGenerator.prepare,
      with: always(always(
        TOTPValue(
          resourceID: .mock_1,
          otp: "123",
          timeLeft: 20,
          period: 30
        )
      ))
    )

    let tested: ResourcesOTPController = try self.testedInstance()
    try await withSerialTaskExecutor {
      let initial: OTPValue = try await tested.revealOTP(.mock_1)
      await verifyIf(
        try await tested.currentOTP.value,
        isEqual: initial
      )
      tested.hideOTP()
      let task: Task<OTPValue?, Never> = .detached {
        try? await tested.currentOTP.value
      }
      await Task.yield()
      task.cancel()
      await verifyIfIsNone(await task.value)
    }
  }
}
