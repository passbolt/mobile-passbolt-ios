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

internal struct ResourcesListController {

  internal var refreshResources: () -> AnyPublisher<Never, TheError>
  internal var resourcesListPublisher: () -> AnyPublisher<Array<ResourcesListViewResourceItem>, Never>
  internal var addResource: () -> Void
  internal var presentResourceDetails: (ResourcesListViewResourceItem) -> Void
  internal var presentResourceMenu: (ResourcesListViewResourceItem) -> Void
  internal var resourceDetailsPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var resourceMenuPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
}

extension ResourcesListController: UIController {

  internal typealias Context = AnyPublisher<ResourcesFilter, Never>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {

    let resources: Resources = features.instance()

    let resourceDetailsIDSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceMenuIDSubject: PassthroughSubject<Resource.ID, Never> = .init()

    func refreshResources() -> AnyPublisher<Never, TheError> {
      resources.refreshIfNeeded()
    }

    func resourcesListPublisher() -> AnyPublisher<Array<ResourcesListViewResourceItem>, Never> {
      resources
        .filteredResourcesListPublisher(context)
        .map { $0.map(ResourcesListViewResourceItem.init(from:)) }
        .eraseToAnyPublisher()
    }

    func addResource() {
      // TODO: out of MVP scope
    }

    func presentResourceDetails(_ resource: ResourcesListViewResourceItem) {
      resourceDetailsIDSubject.send(resource.id)
    }

    func presentResourceMenu(_ resource: ResourcesListViewResourceItem) {
      resourceMenuIDSubject.send(resource.id)
    }

    func resourceDetailsPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDetailsIDSubject.eraseToAnyPublisher()
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuIDSubject.eraseToAnyPublisher()
    }

    return Self(
      refreshResources: refreshResources,
      resourcesListPublisher: resourcesListPublisher,
      addResource: addResource,
      presentResourceDetails: presentResourceDetails,
      presentResourceMenu: presentResourceMenu,
      resourceDetailsPresentationPublisher: resourceDetailsPresentationPublisher,
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher
    )
  }
}
