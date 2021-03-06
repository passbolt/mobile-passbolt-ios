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
import CommonModels
import Crypto
import Features
import NetworkClient

import struct Foundation.Data

#if DEBUG
import Dispatch
#endif

public struct AccountTransfer {
  // Publishes progess, finishes when process is completed or fails if it becomes interrupted.
  public var progressPublisher: () -> AnyPublisher<Progress, Error>
  public var accountDetailsPublisher: () -> AnyPublisher<AccountDetails, Error>
  public var processPayload: @StorageAccessActor (String) -> AnyPublisher<Never, Error>
  public var completeTransfer: @StorageAccessActor (Passphrase) -> AnyPublisher<Never, Error>
  public var avatarPublisher: () -> AnyPublisher<Data, Error>
  public var cancelTransfer: @StorageAccessActor () -> Void
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension AccountTransfer {

  public struct AccountDetails {

    public let domain: URLString
    public let label: String
    public let username: String
  }
}

extension AccountTransfer: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> AccountTransfer {
    let diagnostics: Diagnostics = try await features.instance()
    diagnostics.diagnosticLog("Beginning new account transfer...")
    #if DEBUG
    let mdmSupport: MDMSupport = try await features.instance()
    #endif
    let networkClient: NetworkClient = try await features.instance()
    let accounts: Accounts = try await features.instance()
    let transferState: CurrentValueSubject<AccountTransferState, Error> = .init(.init())
    var transferCancelationCancellable: AnyCancellable?
    _ = transferCancelationCancellable  // silence warning

    #if DEBUG
    if let mdmTransferedAccount: MDMSupport.TransferedAccount = mdmSupport.transferedAccount() {
      let accountAlreadyStored: Bool =
        await accounts
        .storedAccounts()
        .contains(
          where: { stored in
            stored.userID.rawValue == mdmTransferedAccount.userID
              && stored.domain == mdmTransferedAccount.domain
          }
        )
      if !accountAlreadyStored {
        // since this bypass is not a proper app feature we have a bit hacky solution
        // where we set the state before presenting associated views and without informing it
        // this results in view presentation issues and requires some delay
        // which happened to be around 1 sec minimum at the time of writing this code
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          transferState.send(
            .init(
              configuration: AccountTransferConfiguration(
                transferID: "N/A",
                pagesCount: 0,
                userID: mdmTransferedAccount.userID,
                authenticationToken: "N/A",
                domain: mdmTransferedAccount.domain,
                hash: "N/A"
              ),
              account: AccountTransferAccount(
                userID: mdmTransferedAccount.userID,
                fingerprint: .init(rawValue: mdmTransferedAccount.fingerprint),
                armoredKey: ArmoredPGPPrivateKey(rawValue: mdmTransferedAccount.armoredKey)
              ),
              profile: AccountTransferAccountProfile(
                username: mdmTransferedAccount.username,
                firstName: mdmTransferedAccount.firstName,
                lastName: mdmTransferedAccount.lastName,
                avatarImageURL: mdmTransferedAccount.avatarImageURL
              ),
              scanningParts: []
            )
          )
        }
      }
      else {
        diagnostics.debugLog("Skipping account transfer bypass - duplicate account")
      }
    }
    else {
      /* */
    }
    #endif

    let progressPublisher: AnyPublisher<Progress, Error> =
      transferState
      .map { state -> Progress in
        if state.scanningFinished {
          return .scanningFinished
        }
        else if let configuration: AccountTransferConfiguration = state.configuration {
          return .scanningProgress(
            Double(state.nextScanningPage ?? configuration.pagesCount)
              / Double(configuration.pagesCount)
          )
        }
        else {
          return .configuration
        }
      }
      .collectErrorLog(using: diagnostics)
      .eraseToAnyPublisher()

    let accountDetailsPublisher: AnyPublisher<AccountDetails, Error> =
      transferState
      .compactMap { state in
        guard
          let config: AccountTransferConfiguration = state.configuration,
          let profile: AccountTransferAccountProfile = state.profile
        else { return nil }

        return AccountDetails(
          domain: config.domain,
          label: "\(profile.firstName) \(profile.lastName)",
          username: profile.username
        )
      }
      .eraseToAnyPublisher()

    let mediaPublisher: AnyPublisher<Data, Error> =
      transferState
      .compactMap { $0.profile }
      .map {
        networkClient
          .mediaDownload
          .make(
            using: .init(
              urlString: $0.avatarImageURL
            )
          )
          .eraseErrorType()
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    // swift-format-ignore: NoLeadingUnderscores
    @StorageAccessActor func _processPayload(
      _ payload: String,
      using features: FeatureFactory
    ) -> AnyPublisher<Never, Error> {
      diagnostics.diagnosticLog("Processing QR code payload...")
      switch processQRCodePayload(payload, in: transferState.value) {
      case var .success(updatedState):
        // if we have config we can ask for profile,
        // there is no need to do it every time
        // so doing it once when requesting for the next page first time
        if let configuration: AccountTransferConfiguration = updatedState.configuration,
          updatedState.profile == nil
        {
          // since we do this once per process (hopefully)
          // and right after reading initial configuration
          // we can verify immediately if we already have the same account stored
          let accountAlreadyStored: Bool =
            accounts
            .storedAccounts()
            .contains(
              where: { stored in
                stored.userID.rawValue == configuration.userID
                  && stored.domain == configuration.domain
              }
            )

          guard !accountAlreadyStored
          else {
            diagnostics.diagnosticLog("...duplicate account detected, aborting!")
            requestCancelation(
              with: configuration,
              lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
              using: networkClient,
              causedByError: nil
            )
            .handleEvents(receiveCompletion: { completion in
              // we are completing transfer with duplicate regardless the response
              transferState.send(
                completion: .failure(
                  AccountDuplicate
                    .error("Duplicate account used for account transfer")
                    .recording(configuration, for: "configuration")
                )
              )
              cancellables.executeOnFeaturesActor {
                try await features.unload(Self.self)
              }
            })
            .ignoreOutput()
            .sink(receiveCompletion: { _ in })
            .store(in: cancellables)

            return Fail(
              error:
                AccountDuplicate
                .error("Duplicate account used for account transfer")
                .recording(configuration, for: "configuration")
            )
            .eraseToAnyPublisher()
          }

          guard !updatedState.scanningFinished
          else {
            diagnostics.diagnosticLog("...missing profile data, aborting!")
            transferState
              .send(
                completion: .failure(
                  TheErrorLegacy.accountTransferScanningError(
                    context: "account-transfer-complete-missing-profile"
                  )
                )
              )
            cancellables.executeOnFeaturesActor {
              try await features.unload(Self.self)
            }
            return Empty<Never, Error>()
              .eraseToAnyPublisher()
          }

          diagnostics.diagnosticLog("...processing succeeded, continuing transfer...")
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
                avatarImageURL: user.profile.avatar.url.medium
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
        }
        else {
          diagnostics.diagnosticLog("...processing succeeded, continuing transfer...")
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
      case let .failure(error)
      where error.asLegacy.identifier == .canceled:
        diagnostics.diagnosticLog("...processing canceled!")
        return Fail<Never, Error>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error)
      where error.asLegacy.identifier == .accountTransferScanningRecoverableError:
        diagnostics.diagnosticLog("...processing failed, recoverable!")
        return Fail<Never, Error>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error):
        diagnostics.diagnosticLog("...processing failed, aborting!")
        if let configuration: AccountTransferConfiguration = transferState.value.configuration {
          return requestCancelation(
            with: configuration,
            lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
            using: networkClient,
            causedByError: error
          )
          .handleEvents(receiveCompletion: { completion in
            guard case let .failure(error) = completion
            else { unreachable("Cannot complete without an error when processing error") }
            transferState.send(completion: .failure(error))
            cancellables.executeOnFeaturesActor {
              try await features.unload(Self.self)
            }
          })
          .ignoreOutput()  // we care only about completion or failure
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
        else {  // we can't cancel if we don't have configuration yet
          transferState.send(completion: .failure(error))
          cancellables.executeOnFeaturesActor {
            try await features.unload(Self.self)
          }
          return Fail<Never, Error>(error: error)
            .collectErrorLog(using: diagnostics)
            .eraseToAnyPublisher()
        }
      }
    }

    let processPayload: @StorageAccessActor (String) -> AnyPublisher<Never, Error> = { [unowned features] payload in
      _processPayload(payload, using: features)
    }

    @StorageAccessActor func completeTransfer(_ passphrase: Passphrase) -> AnyPublisher<Never, Error> {
      diagnostics.diagnosticLog("Completing account transfer...")
      guard
        let configuration = transferState.value.configuration,
        let account = transferState.value.account,
        let profile = transferState.value.profile
      else {
        diagnostics.diagnosticLog("...missing required data!")
        return Fail<Never, Error>(
          error: TheErrorLegacy.accountTransferScanningRecoverableError(
            context: "account-transfer-complete-invalid-state"
          )
        )
        .eraseToAnyPublisher()
      }
      return cancellables.executeOnStorageAccessActorWithPublisher { [weak features] in
        do {
          try await accounts
            .transferAccount(
              configuration.domain,
              account.userID,
              profile.username,
              profile.firstName,
              profile.lastName,
              profile.avatarImageURL,
              account.fingerprint,
              account.armoredKey,
              passphrase
            )
          diagnostics.diagnosticLog("...account transfer succeeded!")
          transferState.send(completion: .finished)
          try await features?.unload(Self.self)
        }
        catch let error as AccountDuplicate {
          diagnostics.log(error)
          diagnostics.diagnosticLog("...account transfer failed!")
          transferState.send(completion: .failure(error))
          try await features?.unload(Self.self)
        }
        catch {
          diagnostics.log(error)
          diagnostics.diagnosticLog("...account transfer failed!")
          throw error
        }
      }
      .ignoreOutput()
      .eraseToAnyPublisher()
    }

    // swift-format-ignore: NoLeadingUnderscores
    @StorageAccessActor func _cancelTransfer(using features: FeatureFactory) {
      if let configuration: AccountTransferConfiguration = transferState.value.configuration,
        !transferState.value.scanningFinished
      {
        transferCancelationCancellable = requestCancelation(
          with: configuration,
          lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
          using: networkClient
        )
        .collectErrorLog(using: diagnostics)
        // we don't care about response, user exits process anyway
        .sinkDrop()
      }
      else { /* we can't cancel if we don't have configuration yet */
      }
      transferState.send(
        completion: .failure(
          TheErrorLegacy.canceled.appending(context: "account-transfer-scanning-cancel")
        )
      )
      cancellables.executeOnFeaturesActor {
        try await features.unload(Self.self)
      }
    }
    let cancelTransfer: @StorageAccessActor () -> Void = { [unowned features] in
      _cancelTransfer(using: features)
    }

    @FeaturesActor func featureUnload() async throws {
      diagnostics.diagnosticLog("...account transfer process closed!")
      // we should unload this feature after use and it always succeeds
    }

    return Self(
      progressPublisher: { progressPublisher },
      accountDetailsPublisher: { accountDetailsPublisher },
      processPayload: processPayload,
      completeTransfer: completeTransfer,
      avatarPublisher: { mediaPublisher },
      cancelTransfer: cancelTransfer,
      featureUnload: featureUnload
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      progressPublisher: unimplemented("You have to provide mocks for used methods"),
      accountDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      processPayload: unimplemented("You have to provide mocks for used methods"),
      completeTransfer: unimplemented("You have to provide mocks for used methods"),
      avatarPublisher: unimplemented("You have to provide mocks for used methods"),
      cancelTransfer: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}

private func processQRCodePayload(
  _ rawPayload: String,
  in state: AccountTransferState
) -> Result<AccountTransferState, Error> {
  // If state is completed (transferFinished) then we don't expect any next page
  guard let expectedPage: Int = state.nextScanningPage
  else {
    return .failure(
      TheErrorLegacy.canceled
        .appending(context: "account-transfer-scanning-unexpected-page")
        .appending(logMessage: "Processing unexpected page - ignored")
    )
  }

  switch decodeQRCodePart(rawPayload, expectedPage: expectedPage) {
  case let .success(part):
    return updated(state: state, with: part)
  case let .failure(error):
    return .failure(error)
  }
}

private func decodeQRCodePart(
  _ rawPayload: String,
  expectedPage: Int
) -> Result<AccountTransferScanningPart, Error> {
  switch AccountTransferScanningPart.from(qrCode: rawPayload) {
  case let .success(part):
    // Verify if decoded page number is the same as expected
    if part.page == expectedPage {
      /* continue */
    }
    else if part.page == expectedPage - 1 {
      // if we still get previous page we ignore it
      return .failure(
        TheErrorLegacy.canceled
          .appending(
            context: "account-transfer-scanning-repeated-page"
          )
          .appending(
            logMessage: "Repeated QRCode page number"
          )
      )
    }
    else {
      return .failure(
        TheErrorLegacy.accountTransferScanningError(
          context: "decoding-invalid-page"
        )
        .appending(
          logMessage: "Invalid QRCode page"
        )
      )
    }
    return .success(part)
  case let .failure(error):
    return .failure(error)
  }
}

private func updated(
  state: AccountTransferState,
  with part: AccountTransferScanningPart
) -> Result<AccountTransferState, Error> {
  var state: AccountTransferState = state  // make state mutable in scope
  state.scanningParts.append(part)

  switch part.page {
  case 0:
    switch AccountTransferConfiguration.from(part) {
    case let .success(configuration):
      state.configuration = configuration
      return .success(state)
    case let .failure(error):
      return .failure(error)
    }

  case _:
    if state.nextScanningPage == nil {
      guard let hash = state.configuration?.hash, !hash.isEmpty
      else {
        return .failure(
          TheErrorLegacy.accountTransferScanningError(context: "missing-configuration-or-hash")
            .appending(logMessage: "Missing verification hash")
        )
      }
      switch AccountTransferAccount.from(
        Array(state.scanningParts[1..<state.scanningParts.count]),
        verificationHash: hash
      ) {
      case let .success(account):
        state.account = account
        return .success(state)
      case let .failure(error):
        return .failure(error)
      }
    }
    else {
      return .success(state)
    }
  }
}

private func requestNextPage(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<Never, Error> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<Never, Error>(
      error: TheErrorLegacy.accountTransferScanningError(context: "next-page-request-missing-configuration")
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
    .eraseErrorType()
    .ignoreOutput()
    .mapError { $0.asLegacy.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestNextPageWithUserProfile(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<AccountTransferUpdateResponseBody.User, Error> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<AccountTransferUpdateResponseBody.User, Error>(
      error: TheErrorLegacy.accountTransferScanningError(context: "next-page-request-missing-configuration")
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
    .eraseErrorType()
    .map { response -> AnyPublisher<AccountTransferUpdateResponseBody.User, Error> in
      if let user: AccountTransferUpdateResponseBody.User = response.body.user {
        return Just(user)
          .eraseErrorType()
          .eraseToAnyPublisher()
      }
      else {
        return Fail<AccountTransferUpdateResponseBody.User, Error>(
          error: TheErrorLegacy.accountTransferScanningError(context: "next-page-request-missing-user-profile")
            .appending(logMessage: "Missing user profile data")
        )
        .eraseToAnyPublisher()
      }
    }
    .switchToLatest()
    .mapError { $0.asLegacy.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using networkClient: NetworkClient,
  causedByError error: Error? = nil
) -> AnyPublisher<Never, Error> {
  let responsePublisher: AnyPublisher<Void, Error> = networkClient
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
    .eraseErrorType()
    .mapToVoid()
    .eraseToAnyPublisher()
  if let error: Error = error {
    return
      responsePublisher
      .flatMap { _ in Fail<Void, Error>(error: error) }
      .ignoreOutput()
      .eraseToAnyPublisher()
  }
  else {
    return
      responsePublisher
      .ignoreOutput()
      .mapError { error in
        error.asLegacy.appending(context: "account-transfer-scanning-cancelation-request")
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
