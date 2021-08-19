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
import Resources
import UIComponents

internal struct ResourcesSelectionListController {

  internal var refreshResources: () -> AnyPublisher<Never, TheError>
  internal var resourcesListPublisher: () -> AnyPublisher<(suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>), Never>
  internal var addResource: () -> Void
  internal var selectResource: (ResourcesSelectionListViewResourceItem) -> AnyPublisher<Void, TheError>
}

extension ResourcesSelectionListController: UIController {

  internal typealias Context = AnyPublisher<ResourcesFilter, Never>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let autofillContext: AutofillExtensionContext = features.instance()
    let resources: Resources = features.instance()

    func refreshResources() -> AnyPublisher<Never, TheError> {
      resources.refreshIfNeeded()
    }

    func resourcesListPublisher() -> AnyPublisher<(suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>), Never> {
      Publishers.CombineLatest(
        resources
          .filteredResourcesListPublisher(context),
        autofillContext.requestedServiceIdentifiersPublisher()
      )
      .map { resources, requested in
        (
          suggested: resources
            .filter { resource in
              requested.matches(resource)
            }
            .map(ResourcesSelectionListViewResourceItem.init(from:))
            .map(\.suggestionCopy),
          all: resources.map(ResourcesSelectionListViewResourceItem.init(from:))
        )
      }
      .eraseToAnyPublisher()
    }

    func addResource() {
      // TODO: out of MVP scope
    }

    func selectResource(_ resource: ResourcesSelectionListViewResourceItem) -> AnyPublisher<Void, TheError> {
      #warning("TODO: [PAS-224] add resource secret decryption and fill in proper password")
      return Just(Void())
        .setFailureType(to: TheError.self)
        .handleEvents(receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          autofillContext
            .completeWithCredential(
              AutofillExtensionContext.Credential(
                user: resource.username ?? "",
                password: "TODO: PASSWORD"
              )
            )
        })
        .eraseToAnyPublisher()
    }

    return Self(
      refreshResources: refreshResources,
      resourcesListPublisher: resourcesListPublisher,
      addResource: addResource,
      selectResource: selectResource
    )
  }
}

