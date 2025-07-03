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
import Features
import TestExtensions
import XCTest

@testable import NetworkOperations
@testable import PassboltAccountSetup

final class AccountTransferTests: LoadableFeatureTestCase<AccountImport> {

  override class var testedImplementationScope: any FeaturesScope.Type { AccountTransferScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltAccountImport()
  }

  override func prepare() throws {
    set(AccountTransferScope.self)
    use(MDMConfiguration.placeholder)
    patch(
      \MDMConfiguration.preconfiguredAccounts,
      with: always([])
    )
    use(PGP.placeholder)
    use(MediaDownloadNetworkOperation.placeholder)
    use(AccountTransferUpdateNetworkOperation.placeholder)
    use(Accounts.placeholder)
    use(Session.placeholder)
  }

  private var sleepDuration: UInt64 {
    /// defaultTimeout is in seconds
    UInt64(AccountTransferTests.defaultTimeout * 100) * NSEC_PER_MSEC
  }

  func test_scanningProgressPublisher_publishesConfigurationValue_initially() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: AccountImport.Progress?
    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { progress in
          result = progress
        }
      )
      .store(in: cancellables)

    if case .configuration = result {
      /* expected */
    }
    else {
      XCTFail("Invalid initial account transfer progress")
    }
  }

  func test_scanningProgressPublisher_publishesProgressValue_afterProcessingFirstPart() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: AccountImport.Progress?
    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { progress in
          result = progress
        }
      )
      .store(in: cancellables)

    try? await processPart(qrCodePart0, using: accountTransfer)

    if case .scanningProgress(let progressValue) = result {
      XCTAssertEqual(progressValue, 1 / 7)
    }
    else {
      XCTFail("Invalid initial account transfer progress")
    }
  }

  func test_scanningProgressPublisher_publishesFinishedValue_afterProcessingAllParts() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: AccountImport.Progress?
    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { progress in
          result = progress
        }
      )
      .store(in: cancellables)

    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePart1, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)
    try? await processPart(qrCodePart6, using: accountTransfer)

    result =
      try await accountTransfer
      .progressPublisher().asAsyncValue()
    if case .scanningFinished = result {
      /* expected */
    }
    else {
      XCTFail("Invalid account transfer result")
    }
  }

  func test_scanningProgressPublisher_completes_afterCancelation() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: Error?
    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    accountTransfer.cancelTransfer()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertError(result, matches: Cancelled.self)
  }

  func test_scanningProgressPublisher_ignoresInvalidPart() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePartInvalidPageBytes, using: accountTransfer)

    var result: Error?
    accountTransfer
      .progressPublisher()
      .handleErrors({ error in
        result = error
      })
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertNil(result)
  }

  func test_processPayload_fails_withInvalidContent() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: Error?
    accountTransfer
      .processPayload(qrCodePartInvalidPageBytes)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningContentIssue.self
    )
  }

  func test_processPayload_fails_withValidContentAndNetworkResponseFailure() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: Error?
    do {
      _ =
        try await accountTransfer
        .processPayload(qrCodePart0)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_processPayload_succeeds_withValidContent() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    var result: Void?
    let accountTransfer: AccountImport = try testedInstance()

    accountTransfer
      .processPayload(qrCodePart0)
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertNotNil(result)
  }

  func test_processPayload_sendsNextPageRequest_withValidContent() async throws {
    let result: UnsafeSendable<AccountTransferUpdateNetworkOperationVariable> = .init()
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: { (input) async throws in
        result.value = input
        return accountTransferUpdateResponse
      }
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertEqual(result.value?.currentPage, 1)
    XCTAssertEqual(result.value?.status, .inProgress)
  }

  func test_processPayload_ignoresInvalidContentInTheMiddleWithValidConfiguration() async throws {
    let result: UnsafeSendable<AccountTransferUpdateNetworkOperationVariable> = .init()
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: { (input) async throws in
        result.value = input
        return accountTransferUpdateResponse
      }
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    // we have to get configuration before
    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePartInvalidPageBytes, using: accountTransfer)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertEqual(result.value?.currentPage, 1)
    XCTAssertEqual(result.value?.status, .inProgress)
  }

  func test_processPayload_fails_withInvalidVersionByte() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePartInvalidVersionByte)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningContentIssue.self
    )
  }

  func test_processPayload_fails_withInvalidPageBytes() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePartInvalidPageBytes)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningContentIssue.self
    )
  }

  func test_processPayload_fails_withInvalidPageNumber() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePartInvalidPageNumber)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_processPayload_fails_withInvalidConfigurationPart() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePart0InvalidConfiguration)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningContentIssue.self
    )
  }

  func test_processPayload_fails_withInvalidJSONInConfigurationPart() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePart0InvalidJSON)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningContentIssue.self
    )
  }

  func test_processPayload_fails_withInvalidConfigurationDomain() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePart0InvalidDomain)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(
      result,
      matches: AccountTransferScanningDomainIssue.self
    )
  }

  func test_processPayload_fails_withInvalidConfigurationHash() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0InvalidHash, using: accountTransfer)
    try? await processPart(qrCodePart1, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart6)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_processPayload_fails_withInvalidMiddlePart() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePart1Invalid, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart6)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_processPayload_fails_withInvalidJSONInMiddlePart() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePart1, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart6InvalidJSON)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_processPayload_fails_withNoHashInConfig() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0NoHash, using: accountTransfer)
    try? await processPart(qrCodePart1, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart6)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_processPayload_fails_withInvalidContentHash() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePart1Modified, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart6)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertError(
      result,
      matches: AccountTransferScanningFailure.self
    )
  }

  func test_cancelTransfer_sendsCancelationRequest_withConfigurationAvailable() async throws {
    let result: UnsafeSendable<AccountTransferUpdateNetworkOperationVariable> = .init()
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: { (input) async throws in
        result.value = input
        return accountTransferUpdateResponse
      }
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)

    accountTransfer.cancelTransfer()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertEqual(result.value?.currentPage, 0)
    XCTAssertEqual(result.value?.status, .cancel)
  }

  func test_processPayload_fails_withUnexpectedPage() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)
    try? await processPart(qrCodePart1, using: accountTransfer)
    try? await processPart(qrCodePart2, using: accountTransfer)
    try? await processPart(qrCodePart3, using: accountTransfer)
    try? await processPart(qrCodePart4, using: accountTransfer)
    try? await processPart(qrCodePart5, using: accountTransfer)
    try? await processPart(qrCodePart6, using: accountTransfer)

    var result: Error?
    do {
      try await accountTransfer
        .processPayload(qrCodePart7Unexpected)
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: Cancelled.self)
  }

  func test_processPayload_fails_withRepeatedPage() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)
    var result: Error?
    accountTransfer
      .processPayload(qrCodePart0)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertError(result, matches: Cancelled.self)
  }

  func test_processPayload_fails_withDuplicateAccount() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([transferedAccountWithProfile])
    )
    let accountTransfer: AccountImport = try testedInstance()
    var result: Error?

    accountTransfer
      .processPayload(qrCodePart0)
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertError(result, matches: AccountDuplicate.self)
  }

  func test_processPayload_sendsCancelationRequest_withDuplicateAccount() async throws {
    let result: UnsafeSendable<AccountTransferUpdateNetworkOperationVariable> = .init()
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: { (input) async throws in
        result.value = input
        return accountTransferUpdateResponse
      }
    )
    patch(
      \Accounts.storedAccounts,
      with: always([transferedAccountWithProfile])
    )

    let accountTransfer: AccountImport = try testedInstance()

    try? await processPart(qrCodePart0, using: accountTransfer)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertEqual(result.value?.currentPage, 0)
    XCTAssertEqual(result.value?.status, .cancel)
  }

  func test_processPayload_finishesTransferWithDuplicateError_withDuplicateAccount() async throws {
    patch(
      \AccountTransferUpdateNetworkOperation.execute,
      with: always(accountTransferUpdateResponse)
    )
    patch(
      \Accounts.storedAccounts,
      with: always([transferedAccountWithProfile])
    )

    let accountTransfer: AccountImport = try testedInstance()

    var result: Error?
    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    try? await processPart(qrCodePart0, using: accountTransfer)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: sleepDuration)

    XCTAssertError(result, matches: AccountDuplicate.self)
  }
}

extension AccountTransferTests {

  private func processPart(
    _ part: String,
    using accountTransfer: AccountImport
  ) async throws {
    try await accountTransfer
      .processPayload(part)
      .asAsyncValue()
  }
}

private let accountTransferUpdateResponse: AccountTransferUpdateNetworkOperationResult = .init(
  user: .init(
    username: "transferedAccount",
    profile: .init(
      firstName: "firstName",
      lastName: "lastName",
      avatar: .init(
        urlString: "https://passbolt.com/image.jpg"
      )
    )
  )
)

private let transferedAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://localhost:8443",
  userID: .init(uuidString: "f848277c-5398-58f8-a82a-72397af2d450")!,
  fingerprint: "FINGERPRINT"
)

private let transferedAccountWithProfile: AccountWithProfile = .init(
  account: transferedAccount,
  profile: .init(
    accountID: transferedAccount.localID,
    label: "Transfered",
    username: "transfered@account.com",
    firstName: "Transfered",
    lastName: "Account",
    avatarImageURL: ""
  )
)

private let qrCodePart0: String =
  #"""
  100{"transfer_id":"6a63c0f1-1c87-4402-84eb-b3141e1e6397","user_id":"f848277c-5398-58f8-a82a-72397af2d450","domain":"https://localhost:8443","total_pages":7,"hash":"3d84155d3ea079c17221587bbd1fce285b8b636014025e484da01867cf28c0bc22079cac9a268e2ca76d075189065e5426044244b6d0e1a440adda4d89e148fb","authentication_token":"af32cb1f-c1ae-4753-9982-7cc0d2178355"}
  """#
private let qrCodePart1: String =
  #"""
  101{"user_id":"f848277c-5398-58f8-a82a-72397af2d450","fingerprint":"03f60e958f4cb29723acdf761353b5b15d9b054f","armored_key":"-----BEGIN PGP PRIVATE KEY BLOCK-----\r\nVersion: OpenPGP.js v4.10.9\r\nComment: https://openpgpjs.org\r\n\r\nxcaGBFXHTB8BEADAaRMUn++WVatrw3kQK7/6S6DvBauIYcBateuFjczhwEKX\r\nUD6ThLm7nOv5/TKzCpnB5WkP+UZyfT/+jCC2x4+pSgog46jIOuigWBL6Y9F6\r\nKkedApFKxnF6cydxsKxNf/V70Nwagh9ZD4W5ujy+RCB6wYVARDKOlYJnHKWq\r\nco7anGhWYj8KKaDT+7yM7LGy+tCZ96HCw4AvcTb2nXF197Btu2RDWZ/0MhO+\r\nDFuLMITXbhxgQC/eaA1CS6BNS7F91pty7s2hPQgYg3HUaDogTiIyth8R5Inn\r\n9DxlMs6WDXGc6IElSfhCnfcICao22AlM6X3vTxzdBJ0hm0RV3iU1df0J9GoM\r\n7Y7y8OieOJeTI22yFkZpCM8itL+cMjWyiID06dINTRAvN2cHhaLQTfyD1S60\r\nGXTrpTMkJzJHlvjMk0wapNdDM1q3jKZC+9HAFvyVf0UsU156JWtQBfkE1lqA\r\nYxFvMR/ne+kI8+6ueIJNcAtScqh0LpA5uvPjiIjvlZygqPwQ/LUMgxS0P7sP\r\nNzaKiWc9OpUNl4/P3XTboMQ6wwrZ3wOmSYuhFN8ez51U8UpHPSsI8tcHWx66\r\nWsiiAWdAFctpeR/ZuQcXMvgEad57pz/jNN2JHycA+awesPIJieX5QmG44sfx\r\nkOvHqkB3l193yzxu/awYRnWinH71ySW4GJepPQARAQAB/gcDAligwbAF+isJ\r\n5IWTOSV7ntMBT6hJX/lTLRlZuPR8io9niecrRE7UtbHRmW/K02MKr8S9roJF\r\n1/DBPCXC1NBp0WMciZHcqr4dh8DhtvCeSPjJd9L5xMGk9TOrK4BvLurtbly+\r\nqWzP4iRPCLkzX1AbGnBePTLS+tVPHxy4dOMRPqfvzBPLsocHfYXN62osJDtc\r\nHYoFVddQAOPdjsYYptPEI6rFTXNQJTFzwkigqMpTaaqjloM+PFcQNEiabap/\r\nGRCmD4KLUjCw0MJhikJpNzJHU17Oz7mBkkQy0gK7tvXt23TeVZNj3/GXdur7\r\nIUniP0SAdSI6Yby8NPp48SjJ6e5O4HvVMDtBJBiNhHWWepLTPVnd3YeQ+1DY\r\nPmbpTu1zrF4+Bri0TfCuDwcTudYD7UUuS62aOwbE4px+RwBjD299gebnI8YA\r\nlN975eSAZM4r5m
  """#
private let qrCodePart2: String =
  #"""
  102e1dlfDMm47zD9dEmwT+ZwrGfol8oZoUwzYsQaCCmZqaba8\r\n8ieRAZY30R/089RShR5WSieo2iIckFTILWiK/E7VrreCUD8iacutVJqgRdzD\r\ngP4m+Zm3yRJYw2OiFe1ZwzD+Fb0gKDSB67G0i4KuZhXSTvn7QjqDWcVmgDTc\r\nTcrzzTwveeeLYe4aHaMUQGflg+7hsGSt5on/zqrU4DCQtUtFOn3Rsfyi3H4F\r\ni9IA1w1knKVJ5IsIoxdBnRDvM3ZK6STr53I8CIJYB5Jj0cZuJ97pQ2YrFNbP\r\n5rgJCEnGwRuCRzlgaVeji+g27pZpJMJ4MdxAAw1AYo0IOPoNbuts5D/5u5Nz\r\neiXxdQn5i/sfUpYWvVJDnYPpXRT3v4amUpx+NIE5rF2QoHgc0wiw4hpqGVoi\r\nn3WycfvlbnsHFJoR1YI9qS3z09Ihu/NC6TejhgGfcJyRY5ghTvbqjCJmKPya\r\n2/TfvgYtZmQ7toNpAL4VlLKDE55qXmqVbDo0cCuDnXcK/gidC9VEaOxUb3Bx\r\nx0GQkxfiEhp/S/ndxLgyeG8otkGRat6aVjqPoAWj4Eu9w8XVysWPDJVv7hZ6\r\nrEm05a7eqQTUFg8PHw/PdD2CWWYPHVTB+T9ihLwxUHMj4j6Uwvpym2QyIzds\r\nENkC52KY23SWNFE7WjdQmOS8ki1arVNIP9vcmh7nHGrRwPhmFTeTYzM13jER\r\nti8DtvVyqnEf4c6CxfupOKLwRXvtJM9vhgFBD39oP/bPVMee8R8Uj0QUM1ah\r\nVly3WEZK2enFqa/+ChyZ1IOpVm3o2oCZs/SWk/FFsqOsdqJduI/xbk2YG51F\r\nI6bwv2vCXx9+B+VdjDujtwyTpsy+sy2HqTv+SvYMuMFgpkGa7JDa7iuYqZg0\r\n179vEoJJq2E04GSsjpg+IxddtjqMsdM0eCCgbY9QgnMxF1GA01Ij/JC4H8g0\r\n8jNU6RQ4KUaVmwdZvR8BhqNR6Ecx6BfzC415q+klaHf9IiPMFCxy96w/wG6t\r\nGzS2tsczejtDoXmXr8FO+eoDWgzd5uO5f+m1G+dYN4RGUjcVAbC3oePYr3X6\r\noXxu6Cb7tWFzu0ttr2GERFDNy4zeN9UlUbbHGiylMdY9NsuGxC58oBgtHLsA\r\nsxlbw1oQvpXbBWZzfRwowv/znBdfEDm6JoSUnv1pyhBrM6sItolNaY244FKB\r\nmVW46T8U6+sOLSCRAKbKF3BuV6iHZsCtinXvN4asQ/vUepuS59tPhSmqTSIA\r\nK5SCg6FDH/tSOxrG9q187P190Nvc2YyhaolGQmHPK3mkc829sctNIrUJuAyY\r\nB4+WXpM/K0x0u0/GDJsKW26BZvjNH0FkYSBMb3ZlbGFjZSA8YWRhQHBhc3Ni\r\nb2x0
  """#
private let qrCodePart3: String =
  #"""
  103LmNvbT7CwaUEEwEKADgCGwMFCwkIBwMFFQoJCAsFFgIDAQACHgECF4AW\r\nIQQD9g6Vj0yylyOs33YTU7WxXZsFTwUCXRuaLwAhCRATU7WxXZsFTxYhBAP2\r\nDpWPTLKXI6zfdhNTtbFdmwVPjpMP/2/z0VU89P4YHWoHFTWD5/5XJQxbsMKm\r\np8r2LusujAIi1Z+glLcX1Oxh9mksGUq+w/+Ok0pQR78VbzZWETjMe6HWy4Ku\r\nOzicX1AxuTj4uy2YLLhPM4owj1EWU2bttJvq2rbInldM4q4vsSVdPcSa43ZF\r\nx3V9j65FNGHicYROdCbjEda3+xB3wqeOZ1m16DOB/i52nRgtc0h2tVoUiZHm\r\nmMPY6dYIfdwSg/PpJlK5unChI8TeeGKYIxcEnQOtG/gWYF2zIAN+4DUAp2WI\r\n5O7aGkApVG6izGkMRzyIxEwfmYyTSjmJ++NDdi00bQot4qK2kDYF0BFO7VrF\r\nxktLbjDDe8OMmtSOrGFd3wrX4slxcH7mJ44xs5+YV7U44jiyftpHcuTpjWXP\r\ncKX+iKSr+/xdkVMC7AVHx+KJ3TTV7HHZAemaI9R8bdek6ZB52KyrElraDrPd\r\nCZ5cGGx55Iukf4HpGEUkUqQ/8m0nEA0QEkNGjoW4u9VrshWy2Rfdj9ZhCuRi\r\nJyXohYymon7yfBfqGoCPYYmHB4F+oIZLWj6wDWtg3jo5nrENFoyB4q8xSsd2\r\nr2CJDhcCqfL+ik88pwBEPF1KmZqhITYxIFShx9IN7AvhAmfxxix7EUSDdbIm\r\nJyRmoa65DbO5RSOS06gch4edm4rJmNwAy3psR+laKvg6JL0J+B8Ux8aGBFXH\r\nTB8BEADBVmb5bMKAvnRBSEgYSS89F6U0eTPODAp9fbPyC46enRj2wr5RnE+T\r\npf8C+N094TC/G86tfDERoJM4cLAZFFzvhO41Xj47hhb0cEuVvkGMArgJsA4o\r\nw3TIa3r9Zq3VSutb/9lPZLeX2hE1vGSGCLwFi2sP5TB21Zijmt+WQiCVnDbK\r\n76K6NpBlJJTOjatSUMlPqbhjx7r5vtcsGc6QB+aueaTIHzvvSYzFN1xbPnqr\r\n+i1cgP2Ok+2StR/Ip21D5v9urEr5mLE/+MTVaLAv4WvZRRAGrM/621YO7YX3\r\n43uC1jlyQaONIgU5R7DWwhrOQXzQtMJe9fSQwOFfJsIRiJzbREwqxsIN5gZQ\r\n65OY2Kw6uSDFZMl+Gek/BXdnyx5lK9pBXOLwverRkBoTa2wGvxHmgJFjHhcq\r\nf2DltGd19rc+QPpZvqnryWdx3EHfu3Gupj062ElVV4XJcEpMgi5YUScBMEsa\r\n5/mtmU6GDaLS7NbhMurTi2yMoRQUDbEepk2trbZHf/PcCfq/bO12Azsom0
  """#
private let qrCodePart4: String =
  #"""
  1040M\r\nlBoDl7v9JdStI00RCpQvdcCpJncP5SZI2QiDHPykx4gdXu3+TXRbccBK06BG\r\nTi1bpqKdBY0asx6F2SEfTgkjFM1JjLKRh2pRO9Rn8AfQ5AJYL6CT6IcooqSf\r\nz2sN6TsrWZ2/+wPz6EUoxC4AzTyYcQARAQAB/gcDAga+F6ctzqwy5NX7GiZi\r\nEUM2YMwfUv3H/xYb40aNtgQg7R7MuAyLNvseVBVHik/L5PHFAO7xxkS2TE41\r\noj0MMpOOhMPRS0qEQs0zwd4nhKWMNt1TvrProGgF/VUhShwZvHzDpyNo8IAt\r\nl/wmX7diG8mNb01Byr1ZODVtTgOBrgLuwTX/V9IroNHyMoPGR/7MK30cBY20\r\na/Q/ohARUHznYzY7jtFmSslLXu8EKyMRb1YZ9r6Lq11LFL4gOyGb6jo9hQap\r\nSx92KJGixMzXSrVXps27Zco05e8PN8Ak8SFpxuSQGmZ86F1zuiQ+ojXtwt/Q\r\nyd7WkkdchnFRVQaKw9L7IagI8+6ohIL34QRlwF7xoLDK7ipa9OQ1/BmbhKoV\r\n3Q+KpCpTjgx/h2KptXexApDdT6vSJl0JNAMHL44iyaMlY8S+ykLtSRqqw/N7\r\nx5J1g0cHS1+oF0iJ1Z4nzTXfUpYEy7B5vSUd3FuKJ/FYyiHKaCPqZB/fjDUV\r\n+yVqTtzgAF5FMpGNSqZfRsWngo8W/ItKICtXv+iE2fXiwur4dXQqnX18ZvzO\r\nHkTjH0sAeLSp3j4Byoh1AwbTdcwXQqKHx1jHAitzN7oSanNhLDnGazp8VqeC\r\nd/9taEpyF9NvWoJPSels86k43qzcMTS8h2CcU53EYYZYrQhFyQ7N/hzs0Ayu\r\n2dKy59/eiCLbkm8ABvGr9egKK/QZeJElqNES/inhFeQiNmSHA50wr6i9Xx8Q\r\nQdHItMbLPH/RK/jx5tUtUV/aIFbW3mgTBTYSUmZ4xdstG0W7woB+vSHMgc9G\r\nMRlxAcGHcl1k4wcTBN1VAR4BE2lAznUhmg9iIdFZpgTded6i11YTTvLo2m9z\r\np6KDFPL5xMdj61p8ofI2jrccbGFP4ThkRNPexGcROSqMN65oVCClCZOUryb6\r\nm89P0KqAQ8pKLYUfxtM9ebI7SLvXc2sETHOkeSZzwsdFKJef8rcdvDwpD5o2\r\nkzAUXi/ZfXqBAtCQMI7w+krClr1wB3D2934n4d382UQLolGDwftM9xWq3P65\r\nyNbi/TRu+iqP5FNYEO/295QOtAFHzrbH1pfRPGrNo2vTP11+kzwakbMIuSow\r\n5ypHtBEVf8zET9V/rBlGLti+g2AtqKRDEsA59X2q5gJweKjd7wAixWQMJZ4v\r\nN2789nir65t3GhbMzgEweijQV8EaqnT+8rDC/lPcdtSlZ3BG
  """#
private let qrCodePart5: String =
  #"""
  105qptAKwDULVrO\r\nwiLFSnj8uR9e0mCq3wBhEyUQE5IzRAInWClM7T5yN1AaCOtS1zb/8CGdAuE/\r\ninDuGdxAxHmWbpcasqg2xqKvXk3RHWFhL3Q1OL/jMtDrb7tDVIO944rG5eCY\r\nZCwb36noZ8fAKVi5YwAX83GSP6agSYnf1vaqts7t8JTa217CMAlktivsI3wL\r\n2ctPPpgLhvKilbgmwRwdTn3v1ySnAxVpjwSoyLfY254oJwiPytgpIoni9TKq\r\nCNdiZ936MytzkX8OBJapN7rG3TVf+cFbFYGW8BbAckiq3ROiPsiLM1LSMFyu\r\nbC77iE9Ac3zL7EBfG0grN6r+1y5HPfQ6HvMDi9A4wHhqFR81mXFUxIkCSvnk\r\nnDL1kLhFYPjoSFuYGBRITXznfLa/OKGNaxUm+ABAJGsTocpW8XQQTQ87yFQU\r\nu5Wl0uGcYP/HOYVgrEGmqP0g6Tao37lTF+JD4AITn5Y6WtXna7HYPqNwo8WH\r\nhHrYjyX3Na9sjetH4VQLclTt3Mh9/KNKD6+a6MCq9fAPBEfN1HNnW7k6DcDc\r\n+oRgO1bh19SaXAxOp37CwY0EGAEKACACGwwWIQQD9g6Vj0yylyOs33YTU7Wx\r\nXZsFTwUCXRuaPgAhCRATU7WxXZsFTxYhBAP2DpWPTLKXI6zfdhNTtbFdmwVP\r\nFfQQAMA32Wt4eAS+yXgkrz0mrAEuO8Z5cZM2Yex9zMJMsC61V174t/SoAICE\r\nqEbQnw6au7aNWRSo+GRFxpN9o8qilPYpTwZ+Mq64CUn4HMfuhSr/DLvS3aGy\r\nCUBgHK/jLR6bCcbIULxU3DYV75aKXbLl3wMjxccanRsBd6GNPZLv+/WUTKl6\r\nKIQ1uECcYb3hnLDDCKbRGW3I0pc6AZ5PiauhjEAvTN5Npf30tyH4OrJp4Or3\r\niDix+EBW8ZPYokNPzm9Heg1sHRTnCVso9r5tSXwKiQQOOqsOZ1k46z9Q7aZz\r\njlXdflE1G2k1kwEY8mzE4pATEQ5mdw5Wxjtmout5y5HxQkFCeE93VqjPccIm\r\nmlo8jTa4g1bJAuwKiBN/6dBacvI32outOiuJqE1xmUN+4kJFUpNDWDDWWRI3\r\nchlFKQG5FhF7TlRL4Lrwkwoc/7VcwoyBAzZdHuviegwkotpVTN8te48hYfbE\r\n12Bhdwg5JGOIA2Qi/g7uVYzFf28PouSWKOt6kyXnk6a7RuEXmtGfZUC5t/Eq\r\nEmzR5Cfr341ZpVSs0xDTvycX7wYpPq8ffar2L1+lXfxdiXAz2oRrSKXnB+tL\r\nA+4N3m+YaCT0A6VITNja8TWS+nuUS3VN1vdl8BqM8w7cii/l3C+bTOEkNAcW\r\njtIWLmMfQ+CThsB30cGYHyyKjEvh\r\n=J2CF\
  """#
private let qrCodePart6: String =
  #"""
  106r\n-----END PGP PRIVATE KEY BLOCK-----\r\n"}
  """#
private let qrCodePart7Unexpected: String =
  #"""
  106r\n-----END PGP PRIVATE KEY BLOCK-----\r\n"}
  """#
private let qrCodePartInvalidVersionByte: String =
  #"""
  !InvalidVersionByte
  """#
private let qrCodePartInvalidPageBytes: String =
  #"""
  1!!InvalidPageBytes
  """#
private let qrCodePartInvalidPageNumber: String =
  #"""
  1FFInvalidPageNumber
  """#
private let qrCodePart1Invalid: String =
  #"""
  101InvalidMiddlePart
  """#
private let qrCodePart0InvalidConfiguration: String =
  #"""
  100InvalidConfigurationPart
  """#
private let qrCodePart0InvalidJSON: String =
  #"""
  100{"transfer_id":"6a63c0f1-1c87-4402-84eb-b3141e1e6397","user_id":"f848277c-5398-58f8-a82a-72397af2d450","domain":"https://localhost:8443","total_pages":7,"hash":"3d84155d3ea079c17221587bbd1fce285b8b636014025e484da01867cf28c0bc22079cac9a268e2ca76d075189065e5426044244b6d0e1a440adda4d89e148fb","authentication_token":"af32cb1f-c1ae-4753-9982-7cc0d2178355"
  """#
private let qrCodePart0NoHash: String =
  #"""
  100{"transfer_id":"6a63c0f1-1c87-4402-84eb-b3141e1e6397","user_id":"f848277c-5398-58f8-a82a-72397af2d450","domain":"https://localhost:8443","total_pages":7,"hash":"","authentication_token":"af32cb1f-c1ae-4753-9982-7cc0d2178355"}
  """#
private let qrCodePart0InvalidHash: String =
  #"""
  100{"transfer_id":"6a63c0f1-1c87-4402-84eb-b3141e1e6397","user_id":"f848277c-5398-58f8-a82a-72397af2d450","domain":"https://localhost:8443","total_pages":7,"hash":"3d84155d3ea079c17221587bbd1fce285b8b636014025e484da01867cf28c0bc22079cac9a268e2ca76d075189065e5426044244b6d0e1a440adda4d89e148fc","authentication_token":"af32cb1f-c1ae-4753-9982-7cc0d2178355"}
  """#
private let qrCodePart0InvalidDomain: String =
  #"""
  100{"transfer_id":"6a63c0f1-1c87-4402-84eb-b3141e1e6397","user_id":"f848277c-5398-58f8-a82a-72397af2d450","domain":"http://localhost:8443","total_pages":7,"hash":"3d84155d3ea079c17221587bbd1fce285b8b636014025e484da01867cf28c0bc22079cac9a268e2ca76d075189065e5426044244b6d0e1a440adda4d89e148fb","authentication_token":"af32cb1f-c1ae-4753-9982-7cc0d2178355"}
  """#
private let qrCodePart6InvalidJSON: String =
  #"""
  106r\n-----END PGP PRIVATE KEY BLOCK-----\r\n"
  """#
private let qrCodePart6InvalidKey: String =
  #"""
  106r\n-----END INVALID PRIVATE KEY BLOCK-----\r\n"}
  """#
private let qrCodePart1Modified: String =
  #"""
  101{"user_id":"f848277c-5398-58f8-a82a-72397af2d451","fingerprint":"03f60e958f4cb29723acdf761353b5b15d9b054f","armored_key":"-----BEGIN PGP PRIVATE KEY BLOCK-----\r\nVersion: OpenPGP.js v4.10.9\r\nComment: https://openpgpjs.org\r\n\r\nxcaGBFXHTB8BEADAaRMUn++WVatrw3kQK7/6S6DvBauIYcBateuFjczhwEKX\r\nUD6ThLm7nOv5/TKzCpnB5WkP+UZyfT/+jCC2x4+pSgog46jIOuigWBL6Y9F6\r\nKkedApFKxnF6cydxsKxNf/V70Nwagh9ZD4W5ujy+RCB6wYVARDKOlYJnHKWq\r\nco7anGhWYj8KKaDT+7yM7LGy+tCZ96HCw4AvcTb2nXF197Btu2RDWZ/0MhO+\r\nDFuLMITXbhxgQC/eaA1CS6BNS7F91pty7s2hPQgYg3HUaDogTiIyth8R5Inn\r\n9DxlMs6WDXGc6IElSfhCnfcICao22AlM6X3vTxzdBJ0hm0RV3iU1df0J9GoM\r\n7Y7y8OieOJeTI22yFkZpCM8itL+cMjWyiID06dINTRAvN2cHhaLQTfyD1S60\r\nGXTrpTMkJzJHlvjMk0wapNdDM1q3jKZC+9HAFvyVf0UsU156JWtQBfkE1lqA\r\nYxFvMR/ne+kI8+6ueIJNcAtScqh0LpA5uvPjiIjvlZygqPwQ/LUMgxS0P7sP\r\nNzaKiWc9OpUNl4/P3XTboMQ6wwrZ3wOmSYuhFN8ez51U8UpHPSsI8tcHWx66\r\nWsiiAWdAFctpeR/ZuQcXMvgEad57pz/jNN2JHycA+awesPIJieX5QmG44sfx\r\nkOvHqkB3l193yzxu/awYRnWinH71ySW4GJepPQARAQAB/gcDAligwbAF+isJ\r\n5IWTOSV7ntMBT6hJX/lTLRlZuPR8io9niecrRE7UtbHRmW/K02MKr8S9roJF\r\n1/DBPCXC1NBp0WMciZHcqr4dh8DhtvCeSPjJd9L5xMGk9TOrK4BvLurtbly+\r\nqWzP4iRPCLkzX1AbGnBePTLS+tVPHxy4dOMRPqfvzBPLsocHfYXN62osJDtc\r\nHYoFVddQAOPdjsYYptPEI6rFTXNQJTFzwkigqMpTaaqjloM+PFcQNEiabap/\r\nGRCmD4KLUjCw0MJhikJpNzJHU17Oz7mBkkQy0gK7tvXt23TeVZNj3/GXdur7\r\nIUniP0SAdSI6Yby8NPp48SjJ6e5O4HvVMDtBJBiNhHWWepLTPVnd3YeQ+1DY\r\nPmbpTu1zrF4+Bri0TfCuDwcTudYD7UUuS62aOwbE4px+RwBjD299gebnI8YA\r\nlN975eSAZM4r5m
  """#
