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
import Resources
import UIComponents

internal struct ResourcesSelectionListController {

  internal var refreshResources: @MainActor () -> AnyPublisher<Void, Error>
  internal var resourcesListPublisher:
    @MainActor () -> AnyPublisher<
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      ),
      Never
    >
  internal var addResource: @MainActor () -> Void
  internal var resourceCreatePresentationPublisher: @MainActor () -> AnyPublisher<Void, Never>
  internal var selectResource: @MainActor (Resource.ID) -> AnyPublisher<Void, Error>
}

extension ResourcesSelectionListController: UIController {

  internal typealias Context = AnyPublisher<ResourcesFilter, Never>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let autofillContext: AutofillExtensionContext = try await features.instance()
    let resources: Resources = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()

    let resourceCreatePresentationSubject: PassthroughSubject<Void, Never> = .init()

    func refreshResources() -> AnyPublisher<Void, Error> {
      cancellables.executeOnAccountSessionActorWithPublisher {
        return try await sessionData.refreshIfNeeded()
      }
    }

    func resourcesListPublisher() -> AnyPublisher<
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      ),
      Never
    > {
      Publishers.CombineLatest(
        resources
          .filteredResourcesListPublisher(context),
        autofillContext.requestedServiceIdentifiersPublisher()
      )
      .map { resources, requested in
        (
          suggested:
            resources
            .filter { resource in
              requested.matches(resource)
            }
            .map(ResourcesSelectionResourceListItemDSVItem.init(from:))
            .map(\.suggestionCopy),
          all: resources.map(ResourcesSelectionResourceListItemDSVItem.init(from:))
        )
      }
      .eraseToAnyPublisher()
    }

    func addResource() {
      resourceCreatePresentationSubject.send()
    }

    func resourceCreatePresentationPublisher() -> AnyPublisher<Void, Never> {
      resourceCreatePresentationSubject.eraseToAnyPublisher()
    }

    func selectResource(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<Void, Error> {
      return cancellables.executeOnAccountSessionActorWithPublisher {
        return
          resources
          .loadResourceSecret(resourceID)
          .map { resourceSecret -> AnyPublisher<String, Error> in
            if let password: String = resourceSecret.password {
              return Just(password)
                .eraseErrorType()
                .eraseToAnyPublisher()
            }
            else {
              return Fail<String, Error>(error: TheErrorLegacy.invalidResourceSecret())
                .eraseToAnyPublisher()
            }
          }
          .switchToLatest()
          .combineLatest(
            resources
              .resourceDetailsPublisher(resourceID)
              .first()
              .map { $0.username }
          )
          .handleEvents(receiveOutput: { (password, username) in
            autofillContext
              .completeWithCredential(
                AutofillExtensionContext.Credential(
                  user: username ?? "",
                  password: password
                )
              )
          })
          .mapToVoid()
          .collectErrorLog(using: diagnostics)
      }
    }

    return Self(
      refreshResources: refreshResources,
      resourcesListPublisher: resourcesListPublisher,
      addResource: addResource,
      resourceCreatePresentationPublisher: resourceCreatePresentationPublisher,
      selectResource: selectResource
    )
  }
}
