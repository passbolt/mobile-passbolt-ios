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
import Users

import struct Foundation.Date

public struct Resources {

  public var filteredResourcesListPublisher:
    (AnyPublisher<ResourcesFilter, Never>) -> AnyPublisher<Array<ResourceListItemDSV>, Never>
  public var loadResourceSecret: @AccountSessionActor (Resource.ID) -> AnyPublisher<ResourceSecret, Error>
  public var resourceDetailsPublisher: (Resource.ID) -> AnyPublisher<ResourceDetailsDSV, Error>
  public var deleteResource: @AccountSessionActor (Resource.ID) -> AnyPublisher<Void, Error>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension Resources: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountSession: AccountSession = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()

    // initial refresh after loading
    cancellables.executeOnAccountSessionActor {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(error)
      }
    }

    nonisolated func filteredResourcesListPublisher(
      _ filterPublisher: AnyPublisher<ResourcesFilter, Never>
    ) -> AnyPublisher<Array<ResourceListItemDSV>, Never> {
      // trigger refresh on data updates, publishes initially on subscription
      sessionData
        .updatesSequence()
        .map { () -> AnyPublisher<Array<ResourceListItemDSV>, Never> in
          filterPublisher
            .map { filter -> AnyPublisher<Array<ResourceListItemDSV>, Never> in
              accountDatabase
                .fetchResourceListItemDSVs(filter)
                .replaceError(with: Array<ResourceListItemDSV>())
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .asPublisher()
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @AccountSessionActor func loadResourceSecret(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<ResourceSecret, Error> {
      networkClient
        .resourceSecretRequest
        .make(using: .init(resourceID: resourceID.rawValue))
        .eraseErrorType()
        .asyncMap { response throws -> ResourceSecret in
          let decryptedMessage: String =
            try await accountSession
            // We are not using public key yet since we are not
            // managing other users data yet, for now skipping public key
            // for signature verification.
            .decryptMessage(response.body.data, nil)

          if let secret: ResourceSecret = .from(decrypted: decryptedMessage) {
            return secret
          }
          else {
            throw
              TheErrorLegacy
              .invalidResourceSecret()
          }
        }
        .eraseToAnyPublisher()
    }

    nonisolated func resourceDetailsPublisher(
      resourceID: Resource.ID
    ) -> AnyPublisher<ResourceDetailsDSV, Error> {
      sessionData
        .updatesSequence()
        .asPublisher()
        .map {
          accountDatabase
            .fetchResourceDetailsDSVs(.init(resourceID: resourceID))
            .eraseErrorType()
        }
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @AccountSessionActor func deleteResource(
      resourceID: Resource.ID
    ) -> AnyPublisher<Void, Error> {
      networkClient
        .deleteResourceRequest
        .make(using: .init(resourceID: resourceID.rawValue))
        .eraseErrorType()
        .asyncMap { try await sessionData.refreshIfNeeded() }
        .eraseToAnyPublisher()
    }

    @FeaturesActor func featureUnload() async throws {
      /* NOP */
    }

    return Self(
      filteredResourcesListPublisher: filteredResourcesListPublisher,
      loadResourceSecret: loadResourceSecret,
      resourceDetailsPublisher: resourceDetailsPublisher(resourceID:),
      deleteResource: deleteResource(resourceID:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension Resources {

  public static var placeholder: Resources {
    Self(
      filteredResourcesListPublisher: unimplemented("You have to provide mocks for used methods"),
      loadResourceSecret: unimplemented("You have to provide mocks for used methods"),
      resourceDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      deleteResource: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
