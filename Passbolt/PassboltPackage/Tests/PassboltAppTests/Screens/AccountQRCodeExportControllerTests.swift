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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountQRCodeExportControllerTests: LoadableFeatureTestCase<AccountQRCodeExportController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    AccountTransferScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useAccountQRCodeExportController()
  }

  override func prepare() throws {
    set(AccountTransferScope.self)
  }

  func test_viewState_equalsDefault_initially() {
    withTestedInstanceReturnsEqual(
      AccountQRCodeExportController.ViewState(
        currentQRcode: Data(),
        exitConfirmationAlertPresented: false
      )
    ) { feature in
      await feature.viewState.value
    }
  }

  func test_viewState_updatesWithData_whenTransferStateUpdates() {
    let updatesSource: UpdatesSequenceSource = .init()
    patch(
      \AccountChunkedExport.updates,
      with: updatesSource.updatesSequence
    )
    patch(
      \AccountChunkedExport.status,
      with: always(
        .part(0, content: Data([0x65, 0x66]))
      )
    )
    patch(
      \QRCodeGenerator.generateQRCode,
      with: always(Data([0x65, 0x66]))
    )
    withTestedInstanceReturnsEqual(
      AccountQRCodeExportController.ViewState(
        currentQRcode: Data([0x65, 0x66]),
        exitConfirmationAlertPresented: false
      )
    ) { feature in
      await self.mockExecutionControl.addTask {
        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        updatesSource.endUpdates()
      }
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.value
    }
  }

  func test_controller_navigates_whenTransferStateUpdatesToError() {
    XCTExpectFailure(
      "TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified"
    )
    return XCTFail()

    let updatesSource: UpdatesSequenceSource = .init()
    patch(
      \AccountChunkedExport.updates,
      with: updatesSource.updatesSequence
    )
    patch(
      \AccountChunkedExport.status,
      with: always(.error(MockIssue.error()))
    )
    withTestedInstance { feature in
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_controller_navigates_whenTransferStateUpdatesToFinished() {
    XCTExpectFailure(
      "TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified"
    )
    return XCTFail()

    let updatesSource: UpdatesSequenceSource = .init()
    patch(
      \AccountChunkedExport.updates,
      with: updatesSource.updatesSequence
    )
    patch(
      \AccountChunkedExport.status,
      with: always(.finished)
    )
    withTestedInstance { feature in
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_cancelTransfer_cancelsDataExport() {
    patch(
      \AccountChunkedExport.cancel,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.cancelTransfer()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_cancelTransfer_navigates() {
    XCTExpectFailure(
      "TODO: there should be test that checks if navigation was triggered, but that requires update in app navigation to be verified"
    )
    return XCTFail()

    patch(
      \AccountChunkedExport.cancel,
      with: always(Void())
    )
    withTestedInstanceExecuted { feature in
      feature.cancelTransfer()
      await self.mockExecutionControl.executeAll()
    }
  }
}
