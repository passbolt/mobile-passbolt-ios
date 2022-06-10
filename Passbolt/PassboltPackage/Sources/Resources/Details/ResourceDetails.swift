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
import Features
import NetworkClient

// MARK: - Interface

public struct ResourceDetails {

  public var updatesSequence: () -> AnyAsyncSequence<Void>
  public var details: () async throws -> ResourceDetailsDSV
  public var decryptSecret: @AccountSessionActor () async throws -> ResourceSecret
}

extension ResourceDetails: LoadableFeature {

  public typealias Context = Resource.ID
}

// MARK: - Implementation

extension ResourceDetails {

  fileprivate static func load(
    features: FeatureFactory,
    context resourceID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountSession: AccountSession = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()

    let detailsCache: AsyncVariable<ResourceDetailsDSV> = .init(
      initial:
        try await accountDatabase
        .fetchResourceDetailsDSVs(
          .init(
            resourceID: resourceID
          )
        )
    )

    cancellables.executeOnStorageAccessActor {
      for await _ in sessionData.updatesSequence().dropFirst() {
        do {
          let updatedDetails: ResourceDetailsDSV =
            try await accountDatabase
            .fetchResourceDetailsDSVs(
              .init(
                resourceID: resourceID
              )
            )
          try await detailsCache.withValue { (details: inout ResourceDetailsDSV) in
            details = updatedDetails
          }
        }
        catch {
          diagnostics.log(error)
        }
      }
    }
    nonisolated func updatesSequence() -> AnyAsyncSequence<Void> {
      sessionData.updatesSequence()
    }

    @StorageAccessActor func details() async throws -> ResourceDetailsDSV {
      await detailsCache.value
    }

    @AccountSessionActor func decryptSecret() async throws -> ResourceSecret {
      let encryptedSecret: String =
        try await networkClient
        .resourceSecretRequest
        .makeAsync(
          using: .init(
            resourceID: resourceID
          )
        )
        .body
        .data

      let decryptedSecret: String =
        try await accountSession
        // Skipping public key for signature verification.
        .decryptMessage(encryptedSecret, nil)

      return try .from(decrypted: decryptedSecret)
    }

    return ResourceDetails(
      updatesSequence: updatesSequence,
      details: details,
      decryptSecret: decryptSecret
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltResourceDetails() {
    self.use(
      .lazyLoaded(
        ResourceDetails.self,
        load: ResourceDetails.load(features:context:cancellables:)
      )
    )
  }
}

#if DEBUG

extension ResourceDetails {

  public static var placeholder: Self {
    Self(
      updatesSequence: unimplemented(),
      details: unimplemented(),
      decryptSecret: unimplemented()
    )
  }
}
#endif
