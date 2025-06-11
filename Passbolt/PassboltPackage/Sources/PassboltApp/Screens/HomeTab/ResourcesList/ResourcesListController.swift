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
import FeatureScopes
import Metadata
import Resources
import SessionData
import SharedUIComponents
import UIComponents

internal struct ResourcesListController {

  internal var refreshResources: @MainActor () -> AnyPublisher<Void, Error>
  internal var resourcesListPublisher: @MainActor () -> AnyPublisher<Array<ResourcesResourceListItemDSVItem>, Never>
  internal var addResource: @MainActor () -> Void
  internal var presentResourceDetails: @MainActor (ResourcesResourceListItemDSVItem) -> Void
  internal var presentResourceMenu: @MainActor (ResourcesResourceListItemDSVItem) -> Void
  internal var presentResourceCreationMenu: @MainActor () -> Void
  internal var presentDeleteResourceAlert: @MainActor (Resource.ID) -> Void
  internal var resourceMenuPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeleteAlertPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: @MainActor (Resource.ID) -> AnyPublisher<Void, Error>

  internal let features: Features
}

extension ResourcesListController: UIController {

  internal typealias Context = AnyPublisher<ResourcesFilter, Never>

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features = features
    let sessionData: SessionData = try features.instance()
    let resources: ResourcesController = try features.instance()

    let resourceMenuIDSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let navigationToResourceDetails: NavigationToResourceDetails = try features.instance()

    func refreshResources() -> AnyPublisher<Void, Error> {
      Task {
        try await sessionData
          .refreshIfNeeded()
      }
      .asPublisher()
    }

    func resourcesListPublisher() -> AnyPublisher<Array<ResourcesResourceListItemDSVItem>, Never> {
      context.map { filter in
        resources
          .lastUpdate
          .asAnyAsyncSequence()
          .map { _ in
            try await resources.filteredResourcesList(filter)
              .map(ResourcesResourceListItemDSVItem.init(from:))
          }
          .asThrowingPublisher()
          .replaceError(with: .init())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func addResource() {
      cancellables.executeOnMainActor {
        let resourceEditPreparation: ResourceEditPreparation = try features.instance()
        let metadataSettingsService: MetadataSettingsService = try features.instance()

        let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(
          metadataSettingsService.typesSettings().defaultResourceTypeSlug,
          .none,
          .none
        )
        try await features
          .instance(of: NavigationToResourceEdit.self)
          .perform(
            context: .init(
              editingContext: editingContext
            )
          )
      }
    }

    func presentResourceDetails(_ resource: ResourcesResourceListItemDSVItem) {
      cancellables.executeOnMainActor {
        try await navigationToResourceDetails
          .perform(context: resource.id)
      }
    }

    func presentResourceMenu(_ resource: ResourcesResourceListItemDSVItem) {
      resourceMenuIDSubject.send(resource.id)
      cancellables.executeOnMainActor {
        let features: Features =
          try features
          .branchIfNeeded(
            scope: ResourceScope.self,
            context: resource.id
          )

        let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try features.instance()
        try await navigationToResourceContextualMenu
          .perform(
            context: .init()
          )
      }
    }

    func presentDeleteResourceAlert(resourceID: Resource.ID) {
      resourceDeleteAlertPresentationSubject.send(resourceID)
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuIDSubject.eraseToAnyPublisher()
    }

    func resourceDeleteAlertPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDeleteAlertPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeletionPublisher(resourceID: Resource.ID) -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        try await resources
          .delete(resourceID)
      }
    }

    func presentResourceCreationForm() {
      cancellables.executeOnMainActor {
        try features.ensureScope(SessionScope.self)
        let resourceCreatePreparation: ResourceCreatePreparation = try features.instance()
        let context: ResourceCreatingContext = try await resourceCreatePreparation.prepare()
        let navigationToResourceContextualMenu: NavigationToResourceCreateMenu = try features.instance()

        try await navigationToResourceContextualMenu
          .perform(
            context: context
          )
      }
    }

    return Self(
      refreshResources: refreshResources,
      resourcesListPublisher: resourcesListPublisher,
      addResource: addResource,
      presentResourceDetails: presentResourceDetails,
      presentResourceMenu: presentResourceMenu,
      presentResourceCreationMenu: presentResourceCreationForm,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher(resourceID:),
      features: features
    )
  }
}
