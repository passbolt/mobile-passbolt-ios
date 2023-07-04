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
import FeatureScopes
import NetworkOperations
import OSFeatures

import struct CryptoKit.SHA512
import struct Foundation.Data
import class Foundation.JSONEncoder

// MARK: - Implementation

extension AccountChunkedExport {

  fileprivate struct State {

    fileprivate var transferID: String?
    fileprivate var currentTransferPage: Int
    fileprivate var transferDataChunks: Array<Data>
    fileprivate var error: TheError?
  }

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(AccountTransferScope.self)

    let asyncExecutor: AsyncExecutor = try features.instance()

    let accountDataExport: AccountDataExport = try features.instance()
    let transferInitializeNetworkOperation: AccountChunkedExportInitializeNetworkOperation = try features.instance()
    let transferStatusNetworkOperation: AccountChunkedExportStatusNetworkOperation = try features.instance()

    let dataEncoder: JSONEncoder = .init()
    dataEncoder.keyEncodingStrategy = .convertToSnakeCase

    let updatesSource: UpdatesSource = .init()
    let state: CriticalState<State> = .init(
      .init(
        transferID: .none,
        currentTransferPage: 0,
        transferDataChunks: .init(),
        error: .none
      )
    )

    @Sendable nonisolated func status() -> Status {
      state.access { (state: inout State) -> Status in
        if let error: TheError = state.error {
          return .error(error)
        }
        else if state.transferDataChunks.isEmpty || state.transferID == .none {
          return .uninitialized
        }
        else if state.currentTransferPage == state.transferDataChunks.count {
          return .finished
        }
        else {
          let page: Int = state.currentTransferPage
          return .part(page, content: state.transferDataChunks[page])
        }
      }
    }

    @Sendable nonisolated func encodePayload(
      _ transferData: AccountTransferData,
      chunkSize: Int
    ) throws -> (encodedData: Data, pagesCount: Int, dataHash: String) {
      let payload: AccountTransferAccount = .init(
        userID: transferData.userID,
        fingerprint: transferData.fingerprint,
        armoredKey: transferData.armoredKey
      )
      let encodedPayload: Data = try dataEncoder.encode(payload)

      let payloadDataHash: String =
        SHA512
        .hash(data: encodedPayload)
        .compactMap { String(format: "%02x", $0) }
        .joined()

      let numberOfPages: Int =
        encodedPayload.count / chunkSize
        + (encodedPayload.count % chunkSize == 0
          ? 0 : 1)  // add reminder page if needed

      return (
        encodedPayload,
        numberOfPages,
        payloadDataHash
      )
    }

    @Sendable nonisolated func prepareDataChunks(
      transferID: String,
      userID: User.ID,
      authenticationToken: String,
      domain: URLString,
      chunkSize: Int,
      chunkCount: Int,
      payload: Data,
      payloadDataHash: String
    ) throws -> Array<Data> {
      let chunckedPayload: Array<Data> = payload.split(chunkSize: chunkSize)

      let configuration: AccountTransferConfiguration = .init(
        transferID: transferID,
        pagesCount: chunkCount,
        userID: userID,
        authenticationToken: authenticationToken,
        domain: domain,
        hash: payloadDataHash
      )
      let encodedConfiguration: Data = try dataEncoder.encode(configuration)

      var transferDataChunks: Array<Data> = [
        "100".data(using: .ascii)! /* it can't fail */
          + encodedConfiguration
      ]

      for (idx, chunk) in chunckedPayload.enumerated() {
        transferDataChunks
          .append(
            String(
              format: "1%02X",
              arguments: [idx + 1]
            )
            .data(using: .ascii)! /* it can't fail */
              + chunk
          )
      }

      return transferDataChunks
    }

    @Sendable nonisolated func authorize(
      authorizationMethod: AccountExportAuthorizationMethod
    ) async throws {
      // Make sure it won't be called concurrently
      // it does not track ongoing attempts to authorize.
      if let error: TheError = state.get(\.error) {
        throw error
      }
      else if !state.get(\.transferDataChunks.isEmpty) {
        throw
          InternalInconsistency
          .error(
            "Attempting to authorize with ongoing account transfer!"
          )
      }  // else continue

      let transferPayload: AccountTransferData = try await accountDataExport.exportAccountData(authorizationMethod)

      let chunkSize: Int = 1462  // size without chunk prefix which is always 3 bytes ("1" and page number)
      let (encodedPayload, payloadChunkCount, payloadDataHash): (Data, Int, String) = try encodePayload(
        transferPayload,
        chunkSize: chunkSize
      )

      let chunkCount: Int = payloadChunkCount + 1  // add configuration chunk to total count

      let initializationResult: AccountChunkedExportInitializeResponseData =
        try await transferInitializeNetworkOperation(
          .init(
            payloadHash: payloadDataHash,
            totalPagesCount: chunkCount
          )
        )

      let chunkedData: Array<Data> = try prepareDataChunks(
        transferID: initializationResult.id,
        userID: transferPayload.userID,
        authenticationToken: initializationResult.token,
        domain: transferPayload.domain,
        chunkSize: chunkSize,
        chunkCount: chunkCount,
        payload: encodedPayload,
        payloadDataHash: payloadDataHash
      )

      state.access { (state: inout State) in
        state.transferID = initializationResult.id
        state.transferDataChunks = chunkedData
        state.currentTransferPage = 0
      }
      startBackendPolling()
      updatesSource.sendUpdate()
    }

    @Sendable nonisolated func startBackendPolling() {
      asyncExecutor.schedule(.replace) {
        do {
          guard let transferID: String = state.get(\.transferID)
          else {
            throw
              InternalInconsistency
              .error(
                "Attempting to poll transfer status without initializing!"
              )
          }
          while case .part = status() {
            try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
            let updatedStatus = try await transferStatusNetworkOperation(
              .init(
                transferID: transferID
              )
            )

            switch updatedStatus.status {
            case .start:
              state.access { (state: inout State) in
                guard case .none = state.error else { return }
                state.currentTransferPage = updatedStatus.currentPage
                updatesSource.sendUpdate()
              }

            case .inProgress:
              state.access { (state: inout State) in
                state.currentTransferPage = updatedStatus.currentPage
              }
              state.access { (state: inout State) in
                guard case .none = state.error else { return }
                state.currentTransferPage = updatedStatus.currentPage
                updatesSource.sendUpdate()
              }

            case .complete:
              state.access { (state: inout State) in
                guard case .none = state.error else { return }
                state.currentTransferPage = state.transferDataChunks.count
                updatesSource.sendUpdate()
              }
              return  // finished

            case .error:
              throw
                AccountExportFailure
                .error()

            case .cancel:
              throw Cancelled.error()
            }
          }
        }
        catch {
          state.access { (state: inout State) in
            guard case .none = state.error else { return }
            state.error = error.asTheError()
            updatesSource.sendUpdate()
          }
        }
      }
    }

    @Sendable nonisolated func cancel() {
      asyncExecutor.cancelTasks()
      state.access { (state: inout State) in
        guard case .none = state.error else { return }
        state.error = Cancelled.error()
        updatesSource.sendUpdate()
      }
    }

    return .init(
      updates: updatesSource.updates,
      status: status,
      authorize: authorize(authorizationMethod:),
      cancel: cancel
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountChunkedExport() {
    self.use(
      .lazyLoaded(
        AccountChunkedExport.self,
        load: AccountChunkedExport
          .load(features:cancellables:)
      ),
      in: AccountTransferScope.self
    )
  }
}

extension Data {

  fileprivate func split(
    chunkSize: Int
  ) -> Array<Data> {
    let size: Int = self.count
    var offset: Int = 0
    var chunked: Array<Data> = .init()
    while offset < size {
      chunked.append(
        self[
          offset ..< Swift.min(offset + chunkSize, size)
        ]
      )
      offset += chunkSize
    }
    return chunked
  }
}
