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
import CommonDataModels
import Crypto
import Features
import NetworkClient

import struct Foundation.Date

public struct Resources {

  public var refreshIfNeeded: () -> AnyPublisher<Void, TheErrorLegacy>
  public var filteredResourcesListPublisher:
    (AnyPublisher<ResourcesFilter, Never>) -> AnyPublisher<Array<ListViewResource>, Never>
  public var loadResourceSecret: (Resource.ID) -> AnyPublisher<ResourceSecret, TheErrorLegacy>
  public var resourceDetailsPublisher: (Resource.ID) -> AnyPublisher<DetailsViewResource, TheErrorLegacy>
  public var deleteResource: (Resource.ID) -> AnyPublisher<Void, TheErrorLegacy>
  public var featureUnload: () -> Bool
}

extension Resources: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let time: Time = environment.time

    let diagnostics: Diagnostics = features.instance()
    let accountSession: AccountSession = features.instance()
    let accountDatabase: AccountDatabase = features.instance()
    let networkClient: NetworkClient = features.instance()

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
      .filter { /* TODO: verify later $0.last != .none && */ $0.last != $0.current }
      .mapToVoid()
      .sink { [unowned features] in
        features.unload(Resources.self)
      }
      .store(in: cancellables)

    func refreshIfNeeded() -> AnyPublisher<Void, TheErrorLegacy> {
      accountDatabase
        // get info about last successful update
        .fetchLastUpdate()
        .compactMap { lastUpdate -> Date? in
          // since initial application version does not use diff api yet
          // to prevent too many requests (which downloads all resources each time)
          // we are skipping requests that are more frequent than one minute apart
          // so in result you can actually update only once per minute
          // the value will be used with diff api so last used value after update
          // containing diff implementation will be a valid one and immediately used
          //
          // implement diff request here instead when available
          return lastUpdate
        }
        .map { _ -> AnyPublisher<Void, TheErrorLegacy> in
          // refresh resources types
          networkClient
            .resourcesTypesRequest
            .make()
            .map { (response: ResourcesTypesRequestResponse) -> Array<ResourceType> in
              response.body
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
            }
            .map { (resourceTypes: Array<ResourceType>) -> AnyPublisher<Void, TheErrorLegacy> in
              accountDatabase.storeResourcesTypes(resourceTypes)
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { _ -> AnyPublisher<Void, TheErrorLegacy> in
          // refresh resources
          networkClient
            .resourcesRequest
            .make()
            .map { (response: ResourcesRequestResponse) -> Array<Resource> in
              response
                .body
                .map { (resource: ResourcesRequestResponseBodyItem) -> Resource in
                  let permission: ResourcePermission = {
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
                    name: resource.name,
                    url: resource.url,
                    username: resource.username,
                    description: resource.description,
                    permission: permission
                  )
                }
            }
            .map { (resources: Array<Resource>) -> AnyPublisher<Void, TheErrorLegacy> in
              accountDatabase
                .storeResources(resources)
                .map { _ -> AnyPublisher<Void, TheErrorLegacy> in
                  accountDatabase
                    .saveLastUpdate(time.dateNow())
                    .collectErrorLog(using: diagnostics)
                    // if we fail to save last update timestamp the next update
                    // will contain the same changes but it does not affect
                    // final result so no need to propagate that error further
                    .replaceError(with: Void())
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                .switchToLatest()
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          resourcesUpdateSubject.send()
        })
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
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
        accountDatabase.fetchDetailsViewResources(resourceID)
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func deleteResource(resourceID: Resource.ID) -> AnyPublisher<Void, TheErrorLegacy> {
      networkClient
        .deleteResourceRequest
        .make(using: .init(resourceID: resourceID.rawValue))
        .eraseToAnyPublisher()
    }

    func featureUnload() -> Bool {
      // prevent from publishing values after unload
      resourcesUpdateSubject.send(completion: .finished)
      return true
    }

    return Self(
      refreshIfNeeded: refreshIfNeeded,
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
      filteredResourcesListPublisher: unimplemented("You have to provide mocks for used methods"),
      loadResourceSecret: unimplemented("You have to provide mocks for used methods"),
      resourceDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      deleteResource: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
