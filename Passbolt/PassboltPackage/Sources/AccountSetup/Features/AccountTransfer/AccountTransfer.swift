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

// swiftlint:disable file_length
public struct AccountTransfer {
  // Publishes progess, finishes when process is completed or fails if it becomes interrupted.
  public var progressPublisher: () -> AnyPublisher<Progress, TheError>
  public var accountDetailsPublisher: () -> AnyPublisher<AccountDetails, TheError>
  public var processPayload: (String) -> AnyPublisher<Never, TheError>
  public var completeTransfer: (Passphrase) -> AnyPublisher<Never, TheError>
  public var cancelTransfer: () -> Void
  public var featureUnload: () -> Bool
}

extension AccountTransfer {
  
  public struct AccountDetails {
    
    public let domain: String
    public let label: String
    public let username: String
    public let avatarImagePath: String
  }
}

extension AccountTransfer: Feature {
  
  public typealias Environment = Void
  
  // swiftlint:disable:next function_body_length
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountTransfer {
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()
    let accounts: Accounts = features.instance()
    let transferState: CurrentValueSubject<AccountTransferState, TheError> = .init(.init())
    var transferCancelationCancellable: AnyCancellable?
    _ = transferCancelationCancellable // silence warning
    
    func progressPublisher() -> AnyPublisher<Progress, TheError> {
      transferState
        .map { state -> Progress in
          if state.scanningFinished {
            return .scanningFinished
          } else if let configuration: AccountTransferConfiguration = state.configuration {
            return .scanningProgress(
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
    
    func accountDetailsPublisher() -> AnyPublisher<AccountDetails, TheError> {
      transferState
        .compactMap { state in
          guard
            let config: AccountTransferConfiguration = state.configuration,
            let profile: AccountTransferAccountProfile = state.profile
          else { return nil }
          return AccountDetails(
            domain: config.domain,
            label: "\(profile.firstName) \(profile.lastName)",
            username: profile.username,
            avatarImagePath: profile.avatarImagePath
          )
        }
        .eraseToAnyPublisher()
    }
    
    func _processPayload(
      _ payload: String,
      using features: FeatureFactory
    ) -> AnyPublisher<Never, TheError> {
      switch processQRCodePayload(payload, in: transferState.value) {
      // swiftlint:disable:next explicit_type_interface
      case var .success(updatedState):
        // if we have config we can ask for profile,
        // there is no need to do it every time
        // so doing it once when requesting for the next page first time
        if updatedState.configuration != nil, updatedState.scanningParts.count == 1 {
          return requestNextPageWithUserProfile(
            for: updatedState,
            using: networkClient
          )
          .handleEvents(
            receiveOutput: { user in
              updatedState.profile = .init(
                username: user.username,
                firstName: user.profile.firstName,
                lastName: user.profile.lastName,
                avatarImagePath: user.profile.avatar.url.medium
              )
            },
            receiveCompletion: { completion in
              guard case .finished = completion else { return }
              transferState.value = updatedState
            }
          )
          .ignoreOutput()
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        } else {
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
        }
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
            features.unload(Self.self)
          })
          .ignoreOutput() // we care only about completion or failure
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        } else { // we can't cancel if we don't have configuration yet
          transferState.send(completion: .failure(error))
          features.unload(Self.self)
          return Fail<Never, TheError>(error: error)
            .collectErrorLog(using: diagnostics)
            .eraseToAnyPublisher()
        }
      }
    }
    
    // swiftlint:disable:next unowned_variable_capture
    let processPayload: (String) -> AnyPublisher<Never, TheError> = { [unowned features] payload in
      _processPayload(payload, using: features)
    }
    
    func completeTransfer(_ passphrase: Passphrase) -> AnyPublisher<Never, TheError> {
      guard
        let configuration = transferState.value.configuration,
        let account = transferState.value.account,
        let profile = transferState.value.profile
      else {
        return Fail<Never, TheError>(
          error: .accountTransferScanningRecoverableError(
            context: "account-transfer-complete-invalid-state"
          )
        )
        .eraseToAnyPublisher()
      }
      return accounts
        .transferAccount(
          configuration.domain,
          account.userID,
          profile.username,
          profile.firstName,
          profile.lastName,
          profile.avatarImagePath,
          account.fingerprint,
          account.armoredKey,
          passphrase
        )
        .handleEvents(receiveCompletion: { [weak features] completion in
          guard case .finished = completion else { return }
          transferState.send(completion: .finished)
          features?.unload(Self.self)
        })
        .ignoreOutput()
        .eraseToAnyPublisher()
    }
    
    func _cancelTransfer(using features: FeatureFactory) -> Void {
      if
        let configuration: AccountTransferConfiguration = transferState.value.configuration,
        !transferState.value.scanningFinished
      {
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
      features.unload(Self.self)
    }
    // swiftlint:disable:next unowned_variable_capture
    let cancelTransfer: () -> Void = { [unowned features] in
      _cancelTransfer(using: features)
    }
    
    func featureUnload() -> Bool {
      #if DEBUG
      _ = progressPublisher()
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
    
    return Self(
      progressPublisher: progressPublisher,
      accountDetailsPublisher: accountDetailsPublisher,
      processPayload: processPayload,
      completeTransfer: completeTransfer,
      cancelTransfer: cancelTransfer,
      featureUnload: featureUnload
    )
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      progressPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      accountDetailsPublisher:  Commons.placeholder("You have to provide mocks for used methods"),
      processPayload: Commons.placeholder("You have to provide mocks for used methods"),
      completeTransfer: Commons.placeholder("You have to provide mocks for used methods"),
      cancelTransfer: Commons.placeholder("You have to provide mocks for used methods"),
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
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
        status: state.scanningFinished ? .complete : .inProgress,
        requestUserProfile: false
      )
    )
    .ignoreOutput()
    .mapError { $0.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestNextPageWithUserProfile(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<AccountTransferUpdateResponseBody.User, TheError> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<AccountTransferUpdateResponseBody.User, TheError>(
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
        status: state.scanningFinished ? .complete : .inProgress,
        requestUserProfile: true
      )
    )
    .map { response -> AnyPublisher<AccountTransferUpdateResponseBody.User, TheError> in
      if let user: AccountTransferUpdateResponseBody.User = response.body.user {
        return Just(user)
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()
      } else {
        return Fail<AccountTransferUpdateResponseBody.User, TheError>(
          error: .accountTransferScanningError(context: "next-page-request-missing-user-profile")
            .appending(logMessage: "Missing user profile data")
        )
        .eraseToAnyPublisher()
      }
    }
    .switchToLatest()
    .mapError { $0.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using networkClient: NetworkClient,
  causedByError error: TheError? = nil
) -> AnyPublisher<Never, TheError> {
  let responsePublisher: AnyPublisher<Void, TheError> = networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: lastPage,
        status: error == nil ? .cancel : .error,
        requestUserProfile: false
      )
    )
    .map { _ in Void() }
    .eraseToAnyPublisher()
  if let error: TheError = error {
    return responsePublisher
      .flatMap { _ in Fail<Void, TheError>(error: error) }
      .ignoreOutput()
      .eraseToAnyPublisher()
  } else {
    return responsePublisher
      .ignoreOutput()
      .mapError { error in
        error.appending(context: "account-transfer-scanning-cancelation-request")
      }
      .eraseToAnyPublisher()
  }
}

extension AccountTransfer {
  
  public enum Progress {
    
    case configuration
    case scanningProgress(Double)
    case scanningFinished
  }
}