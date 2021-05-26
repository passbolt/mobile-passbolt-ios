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

import Accounts
import Commons
import Crypto
import Features
import NetworkClient
import Safety

public struct AccountTransfer {
  
  public var scanningProgressPublisher: () -> AnyPublisher<ScanningProgress, TheError>
  public var processPayload: (String) -> AnyPublisher<Never, TheError>
  public var completeTransfer: (Passphrase) -> AnyPublisher<Void, TheError>
  public var cancelTransfer: () -> Void
}

extension AccountTransfer: Feature {
  
  public typealias Environment = Void
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> AccountTransfer {
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()
    let accountSession: AccountSession = features.instance()
    let transferState: CurrentValueSubject<AccountTransferState, TheError> = .init(.init())
    var transferCancelationCancellable: AnyCancellable?
    _ = transferCancelationCancellable // silence warning
    
    func scanningProgressPublisher() -> AnyPublisher<ScanningProgress, TheError> {
      transferState
        .map { state -> ScanningProgress in
          if state.scanningFinished {
            return .finished
          } else if let configuration: AccountTransferConfiguration = state.configuration {
            return .progress(
              Double(state.nextScanningPage ?? configuration.pagesCount)
                / Double(configuration.pagesCount)
            )
          } else {
            return .configuration
          }
        }
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }
    
    func processPayload(_ payload: String) -> AnyPublisher<Never, TheError> {
      switch processQRCodePayload(payload, in: transferState.value) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(updatedState):
        return requestNextPage(
          for: updatedState,
          using: networkClient
        )
        .handleEvents(receiveCompletion: { completion in
          guard case .finished = completion else { return }
          transferState.value = updatedState
        })
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error)
      where error.identifier == .canceled
      || error.identifier == .accountTransferScanningRecoverableError:
        return Fail<Never, TheError>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        if let configuration: AccountTransferConfiguration = transferState.value.configuration {
          return requestCancelation(
            with: configuration,
            lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
            using: networkClient,
            causedByError: error
          )
          .handleEvents(receiveCompletion: { completion in
            // swiftlint:disable:next explicit_type_interface
            guard case let .failure(error) = completion
            else { unreachable("Cannot complete without an error when processing error") }
            transferState.send(completion: .failure(error))
          })
          .ignoreOutput() // we care only about completion or failure
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        } else { // we can't cancel if we don't have configuration yet
          transferState.send(completion: .failure(error))
          return Fail<Never, TheError>(error: error)
            .collectErrorLog(using: diagnostics)
            .eraseToAnyPublisher()
        }
      }
    }
    
    func completeTransfer(_ passphrase: Passphrase) -> AnyPublisher<Void, TheError> {
      guard
        let configuration = transferState.value.configuration,
        let account = transferState.value.account
      else {
        return Fail<Void, TheError>(
          error: .accountTransferScanningRecoverableError(
            context: "account-transfer-complete-invalid-state"
          )
        )
        .eraseToAnyPublisher()
      }
      return accountSession
        .completeAccountTransfer(
          configuration.domain,
          account.userID,
          account.fingerprint,
          account.armoredKey,
          passphrase
        )
        .handleEvents(receiveCompletion: { [weak features] completion in
          guard case .finished = completion else { return }
          transferState.send(completion: .finished)
          features?.unload(AccountTransfer.self)
        })
        .eraseToAnyPublisher()
    }
    
    func _cancelTransfer(using features: FeatureFactory) -> Void {
      if let configuration: AccountTransferConfiguration = transferState.value.configuration {
        transferCancelationCancellable = requestCancelation(
          with: configuration,
          lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
          using: networkClient
        )
        .collectErrorLog(using: diagnostics)
        // we don't care about response, user exits process anyway
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
      } else { /* we can't cancel if we don't have configuration yet */ }
      transferState.send(
        completion: .failure(
          .canceled.appending(context: "account-transfer-scanning-cancel")
        )
      )
      features.unload(AccountTransfer.self)
    }
    // swiftlint:disable:next unowned_variable_capture
    let cancelTransfer: () -> Void = { [unowned features] in
      _cancelTransfer(using: features)
    }
    
    return Self(
      scanningProgressPublisher: scanningProgressPublisher,
      processPayload: processPayload,
      completeTransfer: completeTransfer,
      cancelTransfer: cancelTransfer
    )
  }
  
  public func unload() -> Bool {
    #if DEBUG
    _ = scanningProgressPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink(
        receiveCompletion: { _ in /* expected */ },
        receiveValue: { _ in
          assertionFailure("\(Self.self) has to have finished (either completed or canceled) scanning to be unloaded")
        }
      )
    #endif
    return true // we should unload this feature after use and it always succeeds
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      scanningProgressPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      processPayload: Commons.placeholder("You have to provide mocks for used methods"),
      completeTransfer: Commons.placeholder("You have to provide mocks for used methods"),
      cancelTransfer: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

private func processQRCodePayload(
  _ rawPayload: String,
  in state: AccountTransferState
) -> Result<AccountTransferState, TheError> {
  // If state is completed (transferFinished) then we don't expect any next page
  guard let expectedPage: Int = state.nextScanningPage
  else {
    return .failure(
      .canceled
        .appending(context: "account-transfer-scanning-unexpected-page")
        .appending(logMessage: "Processing unexpected page - ignored")
    )
  }
  
  switch decodeQRCodePart(rawPayload, expectedPage: expectedPage) {
  // swiftlint:disable:next explicit_type_interface
  case let .success(part):
    return updated(state: state, with: part)
  // swiftlint:disable:next explicit_type_interface
  case let .failure(error):
    return .failure(error)
  }
}

private func decodeQRCodePart(
  _ rawPayload: String,
  expectedPage: Int
) -> Result<AccountTransferScanningPart, TheError> {
  switch AccountTransferScanningPart.from(qrCode: rawPayload) {
  // swiftlint:disable:next explicit_type_interface
  case let .success(part):
    // Verify if decoded page number is the same as expected
    if part.page == expectedPage {
      /* continue */
    } else if part.page == expectedPage - 1 {
      // if we still get previous page we ignore it
      return .failure(
        .canceled
          .appending(context: "account-transfer-scanning-repeated-page")
          .appending(
            logMessage: "Repeated QRCode page number: \(part.page), expected: \(expectedPage)"
          )
      )
    } else {
      return .failure(
        .accountTransferScanningError(context: "decoding-invalid-page")
          .appending(
            logMessage: "Invalid QRCode page: \(part.page), expected: \(expectedPage)"
          )
      )
    }
    return .success(part)
  // swiftlint:disable:next explicit_type_interface
  case let .failure(error):
    return .failure(error)
  }
}

private func updated(
  state: AccountTransferState,
  with part: AccountTransferScanningPart
) -> Result<AccountTransferState, TheError> {
  var state: AccountTransferState = state // make state mutable in scope
  state.scanningParts.append(part)
  
  switch part.page {
  case 0:
    switch AccountTransferConfiguration.from(part) {
    // swiftlint:disable:next explicit_type_interface
    case let .success(configuration):
      state.configuration = configuration
      return .success(state)
    // swiftlint:disable:next explicit_type_interface
    case let .failure(error):
      return .failure(error)
    }
    
  case _:
    if state.nextScanningPage == nil {
      guard let hash = state.configuration?.hash, !hash.isEmpty
      else {
        return .failure(
          .accountTransferScanningError(context: "missing-configuration-or-hash")
            .appending(logMessage: "Missing verification hash")
        )
      }
      switch AccountTransferAccount.from(
        Array(state.scanningParts[1..<state.scanningParts.count]),
        verificationHash: hash
      ) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(account):
        state.account = account
        return .success(state)
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        return .failure(error)
      }
    } else {
      return .success(state)
    }
  }
}

private func requestNextPage(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<Never, TheError> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<Never, TheError>(
      error: .accountTransferScanningError(context: "next-page-request-missing-configuration")
        .appending(logMessage: "Missing account transfer configuration")
    )
    .eraseToAnyPublisher()
  }
  return networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: state.nextScanningPage
          ?? state.lastScanningPage
          ?? state.configurationScanningPage,
        status: state.scanningFinished ? .complete : .inProgress
      )
    )
    .ignoreOutput()
    .mapError { $0.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using networkClient: NetworkClient,
  causedByError error: TheError? = nil
) -> AnyPublisher<Void, TheError> {
  let responsePublisher: AnyPublisher<Void, TheError> = networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: lastPage,
        status: error == nil ? .cancel : .error
      )
    )
    .map { _ in Void() }
    .mapError { $0.appending(context: "account-transfer-scanning-cancelation-request") }
    .eraseToAnyPublisher()
  
  if let error: TheError = error {
    return responsePublisher
      .mapError { _ in error }
      .flatMap { _ in Fail<Void, TheError>(error: error) }
      .eraseToAnyPublisher()
  } else {
    return responsePublisher
      .eraseToAnyPublisher()
  }
}

extension AccountTransfer {
  
  public enum ScanningProgress {
    
    case configuration
    case progress(Double)
    case finished
  }
}
