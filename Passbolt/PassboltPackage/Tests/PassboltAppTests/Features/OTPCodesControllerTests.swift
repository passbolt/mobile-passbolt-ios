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

import Features
import Foundation
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class OTPCodesControllerTests: LoadableFeatureTestCase<OTPCodesController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltOTPCodesController()
  }

  let timerMockSequence: UpdatesSequenceSource = .init()

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    let sequence = self.timerMockSequence
      .updatesSequence
      .asAnyAsyncSequence()

    patch(
      \OSTime.timerSequence,
      with: always(sequence)
    )
  }

  func test_requestNextFor_throws_whenAccessingResourceSecretFails() {
    patch(
      \OTPResources.secretFor,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: OTPCodesController) in
      try await testedInstance.requestNextFor(.mock_1)
    }
  }

  func test_requestNextFor_returnsOTP_whenAccessingOTPSucceeds() {
    patch(
      \OTPResources.secretFor,
      with: always(
        .init(
          sharedSecret: "MOCK",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: "MOCK",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )
    withTestedInstanceReturnsEqual(
      .totp(
        TOTPValue(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    ) { (testedInstance: OTPCodesController) in
      try await testedInstance.requestNextFor(.mock_1)
    }
  }

  func test_copyFor_throws_whenAccessingResourceSecretFails() {
    patch(
      \OTPResources.secretFor,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: OTPCodesController) in
      try await testedInstance.copyFor(.mock_1)
    }
  }

  func test_copyFor_putsOTPInPasteboard_whenAccessingOTPSucceeds() {
    patch(
      \OTPResources.secretFor,
      with: always(
        .init(
          sharedSecret: "MOCK",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: "MOCK",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )
    patch(
      \OSPasteboard.put,
      with: self.executed(using:)
    )

    withTestedInstanceExecuted(
      using: "123456"
    ) { (testedInstance: OTPCodesController) in
      try await testedInstance.copyFor(.mock_1)
    }
  }

  func test_copyFor_doesNotEndPreviouslyRevealedSequence_whenAccessingSameResource() {
    patch(
      \OTPResources.secretFor,
      with: always(
        .init(
          sharedSecret: "MOCK",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: "MOCK",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )

    withTestedInstanceReturnsSome { (testedInstance: OTPCodesController) in
      _ = try await testedInstance.requestNextFor(.mock_1)
      try await testedInstance.copyFor(.mock_1)
      return await testedInstance.current()
    }
  }

  func test_copyFor_endsPreviouslyRevealedSequence_whenAccessingDifferentResource() {
    patch(
      \OTPResources.secretFor,
      with: always(
        .init(
          sharedSecret: "MOCK",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    patch(
      \OSPasteboard.put,
      with: always(Void())
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: "MOCK_REMOVED",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_2,
        sharedSecret: "MOCK",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_2,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )
    withTestedInstanceReturnsNone { (testedInstance: OTPCodesController) in
      _ = try await testedInstance.requestNextFor(.mock_1)
      try await testedInstance.copyFor(.mock_2)
      return await testedInstance.current()
    }
  }

  func test_dispose_doesNothing_withoutActiveOTP() {
    withTestedInstance { (testedInstance: OTPCodesController) in
      await testedInstance.dispose()
    }
  }

  func test_dispose_cancelsPendingOTPUpdate() {
    patch(
      \OTPResources.secretFor,
      with: { _ in
        try await withTaskCancellationHandler(
          operation: {
            try await Task.never()
          },
          onCancel: {
            self.executed()
          }
        )
      }
    )
    withTestedInstanceExecuted { (testedInstance: OTPCodesController) in
      Task {
        _ = try await testedInstance.requestNextFor(.mock_1)
      }
      try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
      await testedInstance.dispose()
    }
  }

  func test_dispose_clearsActiveOTP() {
    patch(
      \OTPResources.secretFor,
      with: always(
        .init(
          sharedSecret: "MOCK",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    patch(
      \TOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: "MOCK",
        algorithm: .sha1,
        digits: 6,
        period: 30
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          timeLeft: 0,
          period: 30
        )
      )
    )
    withTestedInstanceReturnsNone { (testedInstance: OTPCodesController) in
      _ = try await testedInstance.requestNextFor(.mock_1)
      await testedInstance.dispose()
      return await testedInstance.current()
    }
  }
}
