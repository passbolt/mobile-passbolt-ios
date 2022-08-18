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
import SessionData
import UIComponents

internal struct ResourcesListController {

  internal var refreshResources: @MainActor () -> AnyPublisher<Void, Error>
  internal var resourcesListPublisher: @MainActor () -> AnyPublisher<Array<ResourcesResourceListItemDSVItem>, Never>
  internal var addResource: @MainActor () -> Void
  internal var presentResourceDetails: @MainActor (ResourcesResourceListItemDSVItem) -> Void
  internal var presentResourceMenu: @MainActor (ResourcesResourceListItemDSVItem) -> Void
  internal var presentResourceShare: @MainActor (Resource.ID) -> Void
  internal var presentResourceEdit: @MainActor (Resource.ID) -> Void
  internal var resourceSharePresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceEditPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var presentDeleteResourceAlert: @MainActor (Resource.ID) -> Void
  internal var resourceDetailsPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceMenuPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceCreatePresentationPublisher: @MainActor () -> AnyPublisher<Void, Never>
  internal var resourceDeleteAlertPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: @MainActor (Resource.ID) -> AnyPublisher<Void, Error>
}

extension ResourcesListController: UIController {

  internal typealias Context = AnyPublisher<ResourcesFilter, Never>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionData: SessionData = try await features.instance()
    let resources: Resources = try await features.instance()

    let resourceDetailsIDSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceMenuIDSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceCreatePresentationSubject: PassthroughSubject<Void, Never> = .init()
    let resourceSharePresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceEditPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()

    func refreshResources() -> AnyPublisher<Void, Error> {
      Task {
        try await sessionData
          .refreshIfNeeded()
      }
      .asPublisher()
    }

    func resourcesListPublisher() -> AnyPublisher<Array<ResourcesResourceListItemDSVItem>, Never> {
      resources
        .filteredResourcesListPublisher(context)
        .map { $0.map(ResourcesResourceListItemDSVItem.init(from:)) }
        .eraseToAnyPublisher()
    }

    func addResource() {
      resourceCreatePresentationSubject.send()
    }

    func presentResourceDetails(_ resource: ResourcesResourceListItemDSVItem) {
      resourceDetailsIDSubject.send(resource.id)
    }

    func presentResourceMenu(_ resource: ResourcesResourceListItemDSVItem) {
      resourceMenuIDSubject.send(resource.id)
    }

    func presentDeleteResourceAlert(resourceID: Resource.ID) {
      resourceDeleteAlertPresentationSubject.send(resourceID)
    }

    func resourceDetailsPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDetailsIDSubject.eraseToAnyPublisher()
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuIDSubject.eraseToAnyPublisher()
    }

    func resourceCreatePresentationPublisher() -> AnyPublisher<Void, Never> {
      resourceCreatePresentationSubject.eraseToAnyPublisher()
    }

    func presentResourceShare(resourceID: Resource.ID) {
      resourceSharePresentationSubject.send(resourceID)
    }

    func presentResourceEdit(resourceID: Resource.ID) {
      resourceEditPresentationSubject.send(resourceID)
    }

    func resourceSharePresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceSharePresentationSubject.eraseToAnyPublisher()
    }

    func resourceEditPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceEditPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeleteAlertPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDeleteAlertPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeletionPublisher(resourceID: Resource.ID) -> AnyPublisher<Void, Error> {
        resources
          .deleteResource(resourceID)
          .eraseToAnyPublisher()
    }

    return Self(
      refreshResources: refreshResources,
      resourcesListPublisher: resourcesListPublisher,
      addResource: addResource,
      presentResourceDetails: presentResourceDetails,
      presentResourceMenu: presentResourceMenu,
      presentResourceShare: presentResourceShare(resourceID:),
      presentResourceEdit: presentResourceEdit(resourceID:),
      resourceSharePresentationPublisher: resourceSharePresentationPublisher,
      resourceEditPresentationPublisher: resourceEditPresentationPublisher,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceDetailsPresentationPublisher: resourceDetailsPresentationPublisher,
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceCreatePresentationPublisher: resourceCreatePresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher(resourceID:)
    )
  }
}
