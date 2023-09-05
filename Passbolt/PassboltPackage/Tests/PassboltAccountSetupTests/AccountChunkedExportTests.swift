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

@testable import PassboltAccountSetup

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class AccountChunkedExportTests: LoadableFeatureTestCase<AccountChunkedExport> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    AccountTransferScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltAccountChunkedExport()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(AccountTransferScope.self)
  }

  func test_status_returnsUninitialized_initially() {
    withTestedInstanceReturnsEqual(
      .uninitialized
    ) { feature in
      feature.status()
    }
  }

  func test_status_returnsCancelledError_whenCancelled() {
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status.error(Cancelled.error())
    ) { feature in
      feature.cancel()
      return feature.status()
    }
  }

  func test_authorize_fails_whenExportAuthorizationFails() {
    patch(
      \AccountDataExport.exportAccountData,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.authorize(.biometrics)
    }
  }

  func test_authorize_fails_whenExportInitializationRequestFails() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.authorize(.biometrics)
    }
  }

  func test_authorize_succeeds_whenExportAuthorizationSucceeds() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    withTestedInstanceNotThrows { feature in
      try await feature.authorize(.biometrics)
    }
  }

  func test_authorize_preparesTransferChunks() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: { request in
        self.executed(using: request)
        return .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      }
    )
    withTestedInstanceExecuted(
      using: AccountChunkedExportInitializeRequestData(
        payloadHash: mockDataContentHash,
        totalPagesCount: 2
      )
    ) { feature in
      try await feature.authorize(.biometrics)
    }
  }

  func test_status_returnsFirstPage_afterSuccessfulAthorization() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status
        .part(
          0,
          content: mockDataPart_0
        )
    ) { feature in
      try await feature.authorize(.biometrics)
      return feature.status()
    }
  }

  func test_authorize_startsStatusUpdates_afterSuccessfulAthorization() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    patch(
      \AccountChunkedExportStatusNetworkOperation.execute,
      with: always(
        .init(
          currentPage: 1,
          totalPages: 2,
          status: .inProgress
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status
        .part(
          1,
          content: mockDataPart_1
        ),
      timeout: 1
    ) { feature in
      try await feature.authorize(.biometrics)
      Task { await self.mockExecutionControl.executeAll() }
      return
        try await feature
        .updates
        .asAnyValueAsyncSequence()
        .map { feature.status() }
        .dropFirst()  // skip initial
        .first()  // take first after the update
    }
  }

  func test_status_returnsError_afterUpdatingToError() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    patch(
      \AccountChunkedExportStatusNetworkOperation.execute,
      with: always(
        .init(
          currentPage: 0,
          totalPages: 2,
          status: .error
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status
        .error(AccountExportFailure.error()),
      timeout: 1
    ) { feature in
      try await feature.authorize(.biometrics)
      Task { await self.mockExecutionControl.executeAll() }
      return
        try await feature
        .updates
        .asAnyValueAsyncSequence()
        .map { feature.status() }
        .dropFirst()  // skip initial
        .first()  // take first after the update
    }
  }

  func test_status_ends_afterUpdatingToCancel() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    patch(
      \AccountChunkedExportStatusNetworkOperation.execute,
      with: always(
        .init(
          currentPage: 0,
          totalPages: 2,
          status: .cancel
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status
        .error(Cancelled.error()),
      timeout: 1
    ) { feature in
      try await feature.authorize(.biometrics)
      Task { await self.mockExecutionControl.executeAll() }
      return
        try await feature
        .updates
        .asAnyValueAsyncSequence()
        .map { feature.status() }
        .dropFirst()  // skip initial
        .first()  // take first after the update
    }
  }

  func test_status_ends_afterUpdatingFinished() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    patch(
      \AccountChunkedExportStatusNetworkOperation.execute,
      with: always(
        .init(
          currentPage: 0,
          totalPages: 2,
          status: .cancel
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status.error(Cancelled.error()),
      timeout: 1
    ) { feature in
      try await feature.authorize(.biometrics)
      Task { await self.mockExecutionControl.executeAll() }
      return
        try await feature
        .updates
        .asAnyValueAsyncSequence()
        .map { feature.status() }
        .dropFirst()  // skip initial
        .first()  // take first after the update
    }
  }

  func test_status_updatesWithChunks_afterSuccessfulAthorization() {
    patch(
      \AccountDataExport.exportAccountData,
      with: always(.mock_ada)
    )
    patch(
      \AccountChunkedExportInitializeNetworkOperation.execute,
      with: always(
        .init(
          id: "TRANSFER_ID",
          authenticationToken: "TRANSFER_TOKEN"
        )
      )
    )
    patch(
      \AccountChunkedExportStatusNetworkOperation.execute,
      with: always(
        .init(
          currentPage: 1,
          totalPages: 2,
          status: .inProgress
        )
      )
    )
    withTestedInstanceReturnsEqual(
      AccountChunkedExport.Status
        .part(
          1,
          content: mockDataPart_1
        ),
      timeout: 1
    ) { feature in
      Task {
        try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        await self.mockExecutionControl.executeAll()
      }
      try await feature.authorize(.biometrics)
      return
        try await feature
        .updates
        .asAnyValueAsyncSequence()
        .map { feature.status() }
        .dropFirst()  // skip initial
        .first()  // take first from reminder
    }
  }
}

let mockDataContentHash: String = AccountTransferConfiguration.mock_ada.hash
nonisolated let mockDataPart_0: Data =
  "100".data(using: .ascii)!
  + (try! JSONEncoder.snake.encode(AccountTransferConfiguration.mock_ada))  // current mock data fits in one page
let mockDataPart_1: Data =
  "101".data(using: .ascii)!
  + (try! JSONEncoder.snake.encode(AccountTransferAccount.mock_ada))  // current mock data fits in one page

extension AccountChunkedExportInitializeRequestData: Equatable {

  public static func == (
    _ lhs: AccountChunkedExportInitializeRequestData,
    _ rhs: AccountChunkedExportInitializeRequestData
  ) -> Bool {
    lhs.payloadHash == rhs.payloadHash
      && lhs.totalPagesCount == rhs.totalPagesCount
  }
}
