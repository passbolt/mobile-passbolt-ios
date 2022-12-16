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

import AccountSetup
import Accounts
import Crypto
import NetworkOperations
import OSFeatures
import Session
import struct Foundation.Data

#if DEBUG
import Dispatch
#endif

extension AccountTransfer {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    #warning("Legacy implementation, to be split and refined...")
    let diagnostics: OSDiagnostics = features.instance()
    diagnostics.log(diagnostic: "Beginning new account transfer...")
    #if DEBUG
    let mdmConfiguration: MDMConfiguration = features.instance()
    #endif
    let pgp: PGP = features.instance()
    let session: Session = try await features.instance()
    let accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation = try await features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try await features.instance()
    let accounts: Accounts = try await features.instance()
    let transferState: CurrentValueSubject<AccountTransferState, Error> = .init(.init())
    var transferCancelationCancellable: AnyCancellable?
    _ = transferCancelationCancellable  // silence warning

    #if DEBUG
    if let mdmTransferedAccount: TransferedAccount = mdmConfiguration.preconfiguredAccounts().first {
      let accountAlreadyStored: Bool =
        accounts
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
                fingerprint: mdmTransferedAccount.fingerprint,
                armoredKey: mdmTransferedAccount.armoredKey
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
      .asyncMap {
        try await mediaDownloadNetworkOperation(
          $0.avatarImageURL
        )
      }
      .eraseToAnyPublisher()

    // swift-format-ignore: NoLeadingUnderscores
    func _processPayload(
      _ payload: String,
      using features: FeatureFactory
    ) -> AnyPublisher<Never, Error> {
      diagnostics.log(diagnostic: "Processing QR code payload...")
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
            diagnostics.log(diagnostic: "...duplicate account detected, aborting!")
            requestCancelation(
              with: configuration,
              lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
              using: accountTransferUpdateNetworkOperation,
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
              cancellables.executeOnMainActor {
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
            diagnostics.log(diagnostic: "...missing profile data, aborting!")
            transferState
              .send(
                completion: .failure(
                  AccountTransferScanningFailure.error()
                )
              )
            cancellables.executeOnMainActor {
              try await features.unload(Self.self)
            }
            return Empty<Never, Error>()
              .eraseToAnyPublisher()
          }

          diagnostics.log(diagnostic: "...processing succeeded, continuing transfer...")
          return requestNextPageWithUserProfile(
            for: updatedState,
            using: accountTransferUpdateNetworkOperation
          )
          .handleEvents(
            receiveOutput: { user in
              updatedState.profile = .init(
                username: user.username,
                firstName: user.profile.firstName,
                lastName: user.profile.lastName,
                avatarImageURL: user.profile.avatar.urlString
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
          diagnostics.log(diagnostic: "...processing succeeded, continuing transfer...")
          return requestNextPage(
            for: updatedState,
            using: accountTransferUpdateNetworkOperation
          )
          .handleEvents(receiveCompletion: { completion in
            guard case .finished = completion else { return }
            transferState.value = updatedState
          })
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
      case let .failure(error)
      where error is Cancelled:
        diagnostics.log(diagnostic: "...processing canceled!")
        return Fail<Never, Error>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error)
      where error is AccountTransferScanningIssue || error is AccountTransferScanningContentIssue
        || error is AccountTransferScanningDomainIssue:
        diagnostics.log(diagnostic: "...processing failed, recoverable!")
        return Fail<Never, Error>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error):
        diagnostics.log(diagnostic: "...processing failed, aborting!")
        if let configuration: AccountTransferConfiguration = transferState.value.configuration {
          return requestCancelation(
            with: configuration,
            lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
            using: accountTransferUpdateNetworkOperation,
            causedByError: error
          )
          .handleEvents(receiveCompletion: { completion in
            guard case let .failure(error) = completion
            else { unreachable("Cannot complete without an error when processing error") }
            transferState.send(completion: .failure(error))
            cancellables.executeOnMainActor {
              try await features.unload(Self.self)
            }
          })
          .ignoreOutput()  // we care only about completion or failure
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
        else {  // we can't cancel if we don't have configuration yet
          transferState.send(completion: .failure(error))
          cancellables.executeOnMainActor {
            try await features.unload(Self.self)
          }
          return Fail<Never, Error>(error: error)
            .collectErrorLog(using: diagnostics)
            .eraseToAnyPublisher()
        }
      }
    }

    let processPayload: (String) -> AnyPublisher<Never, Error> = { [unowned features] payload in
      _processPayload(payload, using: features)
    }

    nonisolated func completeTransfer(_ passphrase: Passphrase) -> AnyPublisher<Never, Error> {
      diagnostics.log(diagnostic: "Completing account transfer...")
      guard
        let configuration = transferState.value.configuration,
        let account = transferState.value.account,
        let profile = transferState.value.profile
      else {
        diagnostics.log(diagnostic: "...missing required data!")
        return Fail<Never, Error>(
          error: AccountTransferScanningFailure.error()
        )
        .eraseToAnyPublisher()
      }
      return cancellables.executeAsyncWithPublisher { [weak features] in
        do {
          // verify passphrase
          switch pgp.verifyPassphrase(account.armoredKey, passphrase) {
          case .success:
            break  // continue process

          case let .failure(error):
            diagnostics.log(diagnostic: "...invalid passphrase!")
            throw
              error
              .asTheError()
              .pushing(.message("Invalid passphrase used for account transfer"))
          }
          let addedAccount: Account =
            try accounts
            .addAccount(
              .init(
                userID: account.userID,
                domain: configuration.domain,
                username: profile.username,
                firstName: profile.firstName,
                lastName: profile.lastName,
                avatarImageURL: profile.avatarImageURL,
                fingerprint: account.fingerprint,
                armoredKey: account.armoredKey
              )
            )

          // create new session for transferred account
          _ =
            try await session
            .authorize(
              .adHoc(addedAccount, passphrase, account.armoredKey)
            )

          diagnostics.log(diagnostic: "...account transfer succeeded!")
          transferState.send(completion: .finished)
          try await features?.unload(Self.self)
        }
        catch let error as AccountDuplicate {
          diagnostics.log(error: error)
          diagnostics.log(diagnostic: "...account transfer failed!")
          transferState.send(completion: .failure(error))
          try await features?.unload(Self.self)
        }
        catch let error as SessionMFAAuthorizationRequired {
          diagnostics.log(error: error)
          diagnostics.log(diagnostic: "...account transfer finished, requesting MFA...")
          transferState.send(completion: .finished)
          try await features?.unload(Self.self)
        }
        catch {
          diagnostics.log(error: error)
          diagnostics.log(diagnostic: "...account transfer failed!")
          throw error
        }
      }
      .ignoreOutput()
      .eraseToAnyPublisher()
    }

    // swift-format-ignore: NoLeadingUnderscores
    func _cancelTransfer(using features: FeatureFactory) {
      if let configuration: AccountTransferConfiguration = transferState.value.configuration,
        !transferState.value.scanningFinished
      {
        transferCancelationCancellable = requestCancelation(
          with: configuration,
          lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
          using: accountTransferUpdateNetworkOperation
        )
        .collectErrorLog(using: diagnostics)
        // we don't care about response, user exits process anyway
        .sinkDrop()
      }
      else { /* we can't cancel if we don't have configuration yet */
      }
      transferState.send(
        completion: .failure(
          Cancelled.error()
        )
      )
      cancellables.executeOnMainActor {
        try await features.unload(Self.self)
      }
    }
    let cancelTransfer: () -> Void = { [unowned features] in
      _cancelTransfer(using: features)
    }

    @MainActor func featureUnload() async throws {
      diagnostics.log(diagnostic: "...account transfer process closed!")
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
}

private func processQRCodePayload(
  _ rawPayload: String,
  in state: AccountTransferState
) -> Result<AccountTransferState, Error> {
  // If state is completed (transferFinished) then we don't expect any next page
  guard let expectedPage: Int = state.nextScanningPage
  else {
    return .failure(
      Cancelled.error()
        .pushing(.message("Unexpected QRCode page"))
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
        Cancelled.error()
          .pushing(.message("Duplicate QRCode page"))
      )
    }
    else {
      return .failure(
        AccountTransferScanningFailure.error()
          .pushing(.message("Invalid QRCode page"))
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
          AccountTransferScanningFailure.error()
            .pushing(.message("Missing verification hash"))
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
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation
) -> AnyPublisher<Never, Error> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<Never, Error>(
      error: AccountTransferScanningFailure.error()
        .pushing(.message("Missing transfer configuration"))
    )
    .eraseToAnyPublisher()
  }
  return Just(Void())
    .eraseErrorType()
    .asyncMap {
      try await accountTransferUpdateNetworkOperation(
        .init(
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
    }
    .ignoreOutput()
    .eraseToAnyPublisher()
}

private func requestNextPageWithUserProfile(
  for state: AccountTransferState,
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation
) -> AnyPublisher<AccountTransferUpdateNetworkOperationResult.User, Error> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<AccountTransferUpdateNetworkOperationResult.User, Error>(
      error: AccountTransferScanningFailure.error()
        .pushing(.message("Missing transfer configuration"))
    )
    .eraseToAnyPublisher()
  }
  return Just(Void())
    .eraseErrorType()
    .asyncMap { () async throws -> AccountTransferUpdateNetworkOperationResult.User in
      let user: AccountTransferUpdateNetworkOperationResult.User? = try await accountTransferUpdateNetworkOperation(
        .init(
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
      .user

      if let user = user {
        return user
      }
      else {
        throw AccountTransferScanningFailure.error()
          .pushing(.message("Missing account profile"))
      }
    }
    .eraseToAnyPublisher()
}

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation,
  causedByError error: Error? = nil
) -> AnyPublisher<Never, Error> {
  let responsePublisher: AnyPublisher<Void, Error> =
    Just(Void())
    .eraseErrorType()
    .asyncMap {
      try await accountTransferUpdateNetworkOperation(
        .init(
          domain: configuration.domain,
          authenticationToken: configuration.authenticationToken,
          transferID: configuration.transferID,
          currentPage: lastPage,
          status: error == nil ? .cancel : .error,
          requestUserProfile: false
        )
      )
    }
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
      .eraseToAnyPublisher()
  }
}

extension FeatureFactory {

  internal func usePassboltAccountTransfer() {
    self.use(
      .lazyLoaded(
        AccountTransfer.self,
        load: AccountTransfer
          .load(features:cancellables:)
      )
    )
  }
}
