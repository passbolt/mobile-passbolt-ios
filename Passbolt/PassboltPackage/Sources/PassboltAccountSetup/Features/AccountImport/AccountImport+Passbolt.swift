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
import Commons
import Crypto
import FeatureScopes
import NetworkOperations
import OSFeatures
import Session

import struct Foundation.Data

#if DEBUG
import Dispatch
#endif

extension AccountImport {

  fileprivate struct State: Sendable {

    fileprivate var transferState: AccountTransferState = .init()
    fileprivate var avatar: Data? = nil
    fileprivate var error: Error? = nil
    fileprivate var isCompleted: Bool = false
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(AccountTransferScope.self)

    Diagnostics.logger.info("Beginning new account transfer...")
    #if DEBUG
    let mdmConfiguration: MDMConfiguration = features.instance()
    #endif
    let pgp: PGP = features.instance()
    let accountKitImport: AccountKitImport = try features.instance()
    let session: Session = try features.instance()
    let accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()
    let accounts: Accounts = try features.instance()

    let state: Variable<State> = .init(initial: .init())

    #if DEBUG
    if let mdmTransferedAccount: AccountTransferData = mdmConfiguration.preconfiguredAccounts().first {
      importAccountByPayload(mdmTransferedAccount)
    }
    else {
      /* */
    }
    #endif

    @Sendable nonisolated func progress() -> Progress {
      let transferState = state.value.transferState
      if transferState.scanningFinished {
        return .scanningFinished
      }
      else if let configuration = transferState.configuration {
        return .scanningProgress(
          Double(transferState.nextScanningPage ?? configuration.pagesCount)
            / Double(configuration.pagesCount)
        )
      }
      else {
        return .configuration
      }
    }

    @Sendable nonisolated func accountDetails() -> AccountDetails? {
      let transferState = state.value.transferState
      guard
        let config = transferState.configuration,
        let profile = transferState.profile
      else { return nil }
      return AccountDetails(
        domain: config.domain,
        label: "\(profile.firstName) \(profile.lastName)",
        username: profile.username
      )
    }

    @Sendable nonisolated func avatar() -> Data? {
      state.value.avatar
    }

    @Sendable nonisolated func processPayload(
      _ payload: String
    ) async throws {
      Diagnostics.logger.info("Processing QR code payload...")

      let currentTransferState = state.value.transferState
      switch processQRCodePayload(payload, in: currentTransferState) {
      case .success(var updatedState):
        // If we have a download link it means we are on version 2
        if let downloadLink = updatedState.downloadLink {
          do {
            let accountKit = try await mediaDownloadNetworkOperation.execute(downloadLink.accountKitURL)
            guard let accountKitString = String(data: accountKit, encoding: .utf8), !accountKit.isEmpty
            else {
              throw AccountTransferScanningFailure.error().pushing(.message("Account kit is empty"))
            }
            let accountTransferData = try accountKitImport.importAccountKit(accountKitString)
            importAccountByPayload(accountTransferData)
          }
          catch {
            state.mutate { $0.error = error }
            throw error
          }
          return
        }

        // if we have config we can ask for profile,
        // there is no need to do it every time
        // so doing it once when requesting for the next page first time
        // process payload version 1
        if let configuration = updatedState.configuration,
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
            Diagnostics.logger.info("...duplicate account detected, aborting!")
            // Fire, cancelation request no need to wait for the result
            Task {
              try? await requestCancelation(
                with: configuration,
                lastPage: state.value.transferState.lastScanningPage
                  ?? state.value.transferState.configurationScanningPage,
                using: accountTransferUpdateNetworkOperation,
                causedByError: nil
              )
            }
            let error =
              AccountDuplicate
              .error("Duplicate account used for account transfer")
              .recording(configuration, for: "configuration")
            state.mutate { $0.error = error }
            throw error
          }

          guard !updatedState.scanningFinished
          else {
            Diagnostics.logger.info("...missing profile data, aborting!")
            let error = AccountTransferScanningFailure.error()
            state.mutate { $0.error = error }
            throw error
          }

          Diagnostics.logger.info("...processing succeeded, continuing transfer...")
          do {
            let user = try await requestNextPageWithUserProfile(
              for: updatedState,
              using: accountTransferUpdateNetworkOperation
            )
            updatedState.profile = .init(
              username: user.username,
              firstName: user.profile.firstName,
              lastName: user.profile.lastName,
              avatarImageURL: user.profile.avatar.urlString
            )
            state.mutate { $0.transferState = updatedState }

            // Fetch avatar asynchronously
            if let profile = updatedState.profile {
              Task {
                if let avatarData = try? await mediaDownloadNetworkOperation(profile.avatarImageURL) {
                  state.mutate { $0.avatar = avatarData }
                }
              }
            }
          }
          catch {
            error.logged()
            state.mutate { $0.error = error }
            throw error
          }
        }
        else {
          Diagnostics.logger.info("...processing succeeded, continuing transfer...")
          do {
            try await requestNextPage(
              for: updatedState,
              using: accountTransferUpdateNetworkOperation
            )
            state.mutate { $0.transferState = updatedState }
          }
          catch {
            error.logged()
            state.mutate { $0.error = error }
            throw error
          }
        }

      case .failure(let error) where error is Cancelled:
        Diagnostics.logger.info("...processing canceled!")
        error.logged()
        throw error

      case .failure(let error)
      where error is AccountTransferScanningIssue || error is AccountTransferScanningContentIssue
        || error is AccountTransferScanningDomainIssue:
        Diagnostics.logger.info("...processing failed, recoverable!")
        error.logged()
        throw error

      case .failure(let error):
        Diagnostics.logger.info("...processing failed, aborting!")
        if let configuration = state.value.transferState.configuration {
          do {
            try await requestCancelation(
              with: configuration,
              lastPage: state.value.transferState.lastScanningPage
                ?? state.value.transferState.configurationScanningPage,
              using: accountTransferUpdateNetworkOperation,
              causedByError: error
            )
          }
          catch let cancelError {
            cancelError.logged()
            state.mutate { $0.error = cancelError }
            throw cancelError
          }
        }
        else {
          // we can't cancel if we don't have configuration yet
          state.mutate { $0.error = error }
          throw error
        }
      }
    }

    @Sendable nonisolated func completeTransfer(_ passphrase: Passphrase) async throws {
      Diagnostics.logger.info("Completing account transfer...")
      guard
        let configuration = state.value.transferState.configuration,
        let account = state.value.transferState.account,
        let profile = state.value.transferState.profile
      else {
        Diagnostics.logger.info("...missing required data!")
        let error = AccountTransferScanningFailure.error()
        state.mutate { $0.error = error }
        throw error
      }

      // verify passphrase
      switch pgp.verifyPassphrase(account.armoredKey, passphrase) {
      case .success:
        break  // continue process

      case .failure(let error):
        Diagnostics.logger.info("...invalid passphrase!")
        let theError =
          error
          .asTheError()
          .pushing(.message("Invalid passphrase used for account transfer"))
        throw theError
      }

      do {
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

        Diagnostics.logger.info("...account transfer succeeded!")
        state.mutate { $0.isCompleted = true }
      }
      catch let error as AccountDuplicate {
        Diagnostics.logger.info("...account transfer failed!")
        state.mutate { $0.error = error }
        throw error
      }
      catch let mfaError as SessionMFAAuthorizationRequired {
        Diagnostics.logger.info("...account transfer finished, requesting MFA...")
        state.mutate { $0.isCompleted = true }
        throw mfaError
      }
      catch {
        Diagnostics.logger.info("...account transfer failed!")
        throw error
      }
    }

    @Sendable nonisolated func checkIfAccountExist(_ accountTransferData: AccountTransferData) -> Bool {
      accounts
        .storedAccounts()
        .contains(
          where: { stored in
            stored.userID.rawValue == accountTransferData.userID
              && stored.domain == accountTransferData.domain
          }
        )
    }

    @Sendable nonisolated func importAccountByPayload(_ accountTransferData: AccountTransferData) {
      // Use guard to check if the account already exists and exit early if it does
      guard !checkIfAccountExist(accountTransferData) else {
        Diagnostics.debug("Skipping account transfer bypass - duplicate account")
        return
      }

      state.mutate { mutableState in
        mutableState.transferState = .init(
          configuration: AccountTransferConfiguration(
            transferID: "N/A",
            pagesCount: 0,
            userID: accountTransferData.userID,
            authenticationToken: "N/A",
            domain: accountTransferData.domain,
            hash: "N/A"
          ),
          account: AccountTransferAccount(
            userID: accountTransferData.userID,
            fingerprint: accountTransferData.fingerprint,
            armoredKey: accountTransferData.armoredKey
          ),
          profile: AccountTransferAccountProfile(
            username: accountTransferData.username,
            firstName: accountTransferData.firstName,
            lastName: accountTransferData.lastName,
            avatarImageURL: accountTransferData.avatarImageURL ?? ""
          ),
          scanningParts: []
        )
      }
    }

    @Sendable nonisolated func cancelTransfer() {
      if let configuration = state.value.transferState.configuration,
        !state.value.transferState.scanningFinished
      {
        // Fire, cancellation no need to wait for the result
        Task {
          try? await requestCancelation(
            with: configuration,
            lastPage: state.value.transferState.lastScanningPage
              ?? state.value.transferState.configurationScanningPage,
            using: accountTransferUpdateNetworkOperation
          )
        }
      }
      else { /* we can't cancel if we don't have configuration yet */
      }
      state.mutate { $0.error = Cancelled.error() }
    }

    return .init(
      updates: state.map { _ in () }.asAnyUpdatable(),
      progress: progress,
      accountDetails: accountDetails,
      avatar: avatar,
      processPayload: processPayload(_:),
      completeTransfer: completeTransfer(_:),
      checkIfAccountExist: checkIfAccountExist,
      importAccountByPayload: importAccountByPayload(_:),
      cancelTransfer: cancelTransfer
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
  case .success(let part):
    return updated(state: state, with: part)
  case .failure(let error):
    return .failure(error)
  }
}

private func decodeQRCodePart(
  _ rawPayload: String,
  expectedPage: Int
) -> Result<AccountTransferScanningPart, Error> {
  switch AccountTransferScanningPart.from(qrCode: rawPayload) {
  case .success(let part):
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
  case .failure(let error):
    return .failure(error)
  }
}

private func updated(
  state: AccountTransferState,
  with part: AccountTransferScanningPart
) -> Result<AccountTransferState, Error> {
  var mutableState = state  // make state mutable in scope
  mutableState.scanningParts.append(part)

  // We support two kind of version regarding QR code version 1 and version 2
  if part.version == "1" {
    return handleVersion1(state: &mutableState, part: part)
  }
  else if part.version == "2" {
    return handleAccountKitQRCode(state: &mutableState, part: part)
  }
  return .failure(
    AccountTransferScanningFailure.error()
      .pushing(.message("Unsupported QRCode version"))
  )
}

private func handleVersion1(
  state: inout AccountTransferState,
  part: AccountTransferScanningPart
) -> Result<AccountTransferState, Error> {

  switch part.page {
  case 0:
    switch AccountTransferConfiguration.from(part) {
    case .success(let configuration):
      state.configuration = configuration
      return .success(state)
    case .failure(let error):
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
        Array(state.scanningParts[1 ..< state.scanningParts.count]),
        verificationHash: hash
      ) {
      case .success(let account):
        state.account = account
        return .success(state)
      case .failure(let error):
        return .failure(error)
      }
    }
    else {
      return .success(state)
    }
  }
}

private func handleAccountKitQRCode(
  state: inout AccountTransferState,
  part: AccountTransferScanningPart
) -> Result<AccountTransferState, Error> {
  // Scan is finished download payload from gist
  guard let payload = String(data: part.payload, encoding: .utf8) else {
    return .failure(
      AccountTransferScanningFailure.error()
        .pushing(.message("Invalid payload type"))
    )
  }
  do {
    state.downloadLink = try AccountTransferLink.from(payload).get()
  }
  catch {
    return .failure(
      AccountTransferScanningFailure.error()
        .pushing(.message("Failed to extract download link from payload"))
    )
  }
  return .success(state)
}

private func requestNextPage(
  for state: AccountTransferState,
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation
) async throws {
  guard let configuration = state.configuration
  else {
    throw AccountTransferScanningFailure.error()
      .pushing(.message("Missing transfer configuration"))
  }
  _ = try await accountTransferUpdateNetworkOperation(
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

private func requestNextPageWithUserProfile(
  for state: AccountTransferState,
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation
) async throws -> AccountTransferUpdateNetworkOperationResult.User {
  guard let configuration = state.configuration
  else {
    throw AccountTransferScanningFailure.error()
      .pushing(.message("Missing transfer configuration"))
  }
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

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using accountTransferUpdateNetworkOperation: AccountTransferUpdateNetworkOperation,
  causedByError error: Error? = nil
) async throws {
  _ = try await accountTransferUpdateNetworkOperation(
    .init(
      domain: configuration.domain,
      authenticationToken: configuration.authenticationToken,
      transferID: configuration.transferID,
      currentPage: lastPage,
      status: error == nil ? .cancel : .error,
      requestUserProfile: false
    )
  )

  if let error = error {
    throw error
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountImport() {
    self.use(
      .lazyLoaded(
        AccountImport.self,
        load: AccountImport
          .load(features:)
      ),
      in: AccountTransferScope.self
    )
  }
}
