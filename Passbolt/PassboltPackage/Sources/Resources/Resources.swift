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

import struct Foundation.Date

public struct Resources {

  public var refreshIfNeeded: () -> AnyPublisher<Void, TheErrorLegacy>
  public var updatesPublisher: () -> AnyPublisher<Void, Never>
  public var filteredResourcesListPublisher:
    (AnyPublisher<ResourcesFilter, Never>) -> AnyPublisher<Array<ListViewResource>, Never>
  public var loadResourceSecret: (Resource.ID) -> AnyPublisher<ResourceSecret, TheErrorLegacy>
  public var resourceDetailsPublisher: (Resource.ID) -> AnyPublisher<DetailsViewResource, TheErrorLegacy>
  public var deleteResource: (Resource.ID) -> AnyPublisher<Void, TheErrorLegacy>
  public var featureUnload: () -> Bool
}

extension Resources: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let time: Time = environment.time

    let diagnostics: Diagnostics = features.instance()
    let accountSession: AccountSession = features.instance()
    let accountDatabase: AccountDatabase = features.instance()
    let networkClient: NetworkClient = features.instance()
    let featureConfig: FeatureConfig = features.instance()
    let folders: Folders = features.instance()

    let foldersEnabled: Bool
    switch featureConfig.configuration(for: FeatureFlags.Folders.self) {
    case .disabled:
      foldersEnabled = false

    case .enabled:
      foldersEnabled = true
    }

    let resourcesUpdateSubject: CurrentValueSubject<Void, Never> = .init(Void())

    accountSession
      .statePublisher()
      .scan(
        (
          last: Optional<Account.LocalID>.none,
          current: Optional<Account.LocalID>.none
        )
      ) { changes, sessionState in
        switch sessionState {
        case let .authorized(account):
          return (last: changes.current, current: account.localID)

        case let .authorizedMFARequired(account, _):
          return (last: changes.current, current: account.localID)

        case let .authorizationRequired(account):
          return (last: changes.current, current: account.localID)

        case .none:
          return (last: changes.current, current: nil)
        }
      }
      .filter { $0.last != $0.current }
      .mapToVoid()
      .sink { [unowned features] in
        features.unload(Resources.self)
      }
      .store(in: cancellables)

    func refreshIfNeeded() -> AnyPublisher<Void, TheErrorLegacy> {
      return Future<Void, Error> { promise in
        Task {
          do {
            // implement diff request here instead when available
            let _ /*lastUpdate*/ : Date? = try await accountDatabase.fetchLastUpdate()
            if foldersEnabled {
              try await folders.refreshIfNeeded()
            }
            else { /* NOP */ }
            let resourceTypes: Array<ResourceType> =
            try await networkClient
              .resourcesTypesRequest
              .makeAsync()
              .body
              .map { (type: ResourcesTypesRequestResponseBodyItem) -> ResourceType in
                let fields: Array<ResourceProperty> = type
                  .definition
                  .resourceProperties
                  .compactMap { property -> ResourceProperty? in
                    switch property {
                    case let .string(name, isOptional, maxLength):
                      return .init(
                        name: name,
                        typeString: "string",
                        required: !isOptional,
                        encrypted: false,
                        maxLength: maxLength
                      )
                    }
                  }

                let secretFields: Array<ResourceProperty> = type
                  .definition
                  .secretProperties
                  .compactMap { property -> ResourceProperty? in
                    switch property {
                    case let .string(name, isOptional, maxLength):
                      return .init(
                        name: name,
                        typeString: "string",
                        required: !isOptional,
                        encrypted: true,
                        maxLength: maxLength
                      )
                    }
                  }

                return ResourceType(
                  id: .init(rawValue: type.id),
                  slug: .init(rawValue: type.slug),
                  name: type.name,
                  fields: fields + secretFields
                )
              }

            try await accountDatabase.storeResourcesTypes(resourceTypes)

            let resources: Array<Resource> =
            try await networkClient
              .resourcesRequest
              .makeAsync()
              .body
              .map { (resource: ResourcesRequestResponseBodyItem) -> Resource in
                let permission: Permission = {
                  switch resource.permission {
                  case .read:
                    return .read

                  case .write:
                    return .write

                  case .owner:
                    return .owner
                  }
                }()
                return Resource(
                  id: .init(rawValue: resource.id),
                  typeID: .init(rawValue: resource.resourceTypeID),
                  parentFolderID: resource.parentFolderID.map(Folder.ID.init(rawValue:)),
                  name: resource.name,
                  url: resource.url,
                  username: resource.username,
                  description: resource.description,
                  permission: permission,
                  favorite: resource.favorite,
                  modified: resource.modified
                )
              }

            try await accountDatabase.storeResources(resources)

            try await accountDatabase.saveLastUpdate(time.dateNow())
            resourcesUpdateSubject.send()
            if foldersEnabled {
              await folders.resourcesUpdated()
            }
            else { /* NOP */ }
            promise(.success(Void()))
          }
          catch {
            promise(.failure(error))
          }
        }
      }
      .mapErrorsToLegacy()
      .collectErrorLog(using: diagnostics)
      .eraseToAnyPublisher()
    }

    func updatesPublisher() -> AnyPublisher<Void, Never> {
      resourcesUpdateSubject.eraseToAnyPublisher()
    }

    func filteredResourcesListPublisher(
      _ filterPublisher: AnyPublisher<ResourcesFilter, Never>
    ) -> AnyPublisher<Array<ListViewResource>, Never> {
      filterPublisher
        .removeDuplicates()
        .map { filter -> AnyPublisher<Array<ListViewResource>, Never> in
          // trigger refresh on data updates, publishes initially on subscription
          resourcesUpdateSubject
            .map { () -> AnyPublisher<Array<ListViewResource>, Never> in
              accountDatabase
                .fetchListViewResources(filter)
                .replaceError(with: Array<ListViewResource>())
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func loadResourceSecret(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<ResourceSecret, TheErrorLegacy> {
      networkClient
        .resourceSecretRequest
        .make(using: .init(resourceID: resourceID.rawValue))
        .mapErrorsToLegacy()
        .map { response -> AnyPublisher<ResourceSecret, TheErrorLegacy> in
          accountSession
            // We are not using public key yet since we are not
            // managing other users data yet, for now skipping public key
            // for signature verification.
            .decryptMessage(response.body.data, nil)
            .map { decryptedMessage -> AnyPublisher<ResourceSecret, TheErrorLegacy> in
              if let secret: ResourceSecret = .from(decrypted: decryptedMessage) {
                return Just(secret)
                  .setFailureType(to: TheErrorLegacy.self)
                  .eraseToAnyPublisher()
              }
              else {
                return Fail<ResourceSecret, TheErrorLegacy>(error: .invalidResourceSecret())
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func resourceDetailsPublisher(
      resourceID: Resource.ID
    ) -> AnyPublisher<DetailsViewResource, TheErrorLegacy> {
      resourcesUpdateSubject.map {
        accountDatabase
          .fetchDetailsViewResources(resourceID)
          .mapErrorsToLegacy()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func deleteResource(
      resourceID: Resource.ID
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      networkClient
        .deleteResourceRequest
        .make(using: .init(resourceID: resourceID.rawValue))
        .mapErrorsToLegacy()
        .map { refreshIfNeeded() }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func featureUnload() -> Bool {
      // prevent from publishing values after unload
      resourcesUpdateSubject.send(completion: .finished)
      return true
    }

    return Self(
      refreshIfNeeded: refreshIfNeeded,
      updatesPublisher: updatesPublisher,
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
      refreshIfNeeded: unimplemented("You have to provide mocks for used methods"),
      updatesPublisher: unimplemented("You have to provide mocks for used methods"),
      filteredResourcesListPublisher: unimplemented("You have to provide mocks for used methods"),
      loadResourceSecret: unimplemented("You have to provide mocks for used methods"),
      resourceDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      deleteResource: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
