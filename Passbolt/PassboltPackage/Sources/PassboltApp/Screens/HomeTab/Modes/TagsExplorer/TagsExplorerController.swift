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
import NetworkClient
import Resources
import SharedUIComponents
import UIComponents

@MainActor
internal struct TagsExplorerController {

  internal let viewState: ObservableValue<ViewState>
  internal var refreshIfNeeded: @MainActor () async -> Void
  internal var presentTagContent: @MainActor (ResourceTagDSV) -> Void
  internal var presentResourceCreationFrom: @MainActor () -> Void
  internal var presentResourceDetails: @MainActor (Resource.ID) -> Void
  internal var presentResourceMenu: @MainActor (Resource.ID) async -> Void
  internal var presentHomePresentationMenu: @MainActor () async -> Void
  internal var presentAccountMenu: @MainActor () async -> Void
}

extension TagsExplorerController: ComponentController {

  internal typealias ControlledView = TagsExplorerView
  internal typealias NavigationContext = ResourceTagDSV?

  internal static func instance(
    context: NavigationContext,
    navigation: ComponentNavigation<NavigationContext>,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountSettings: AccountSettings = try await features.instance()
    let resources: Resources = try await features.instance()
    let resourceTags: ResourceTags = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()

    let viewState: ObservableValue<ViewState>

    if let resourceTag: ResourceTagDSV = context {
      viewState = .init(
        initial: .init(
          title: .raw(resourceTag.slug.rawValue),
          resourceTagID: resourceTag.id,
          // temporarily disable create for tags
          canCreateResources: false
        )
      )

      // refresh the list based on filters data
      cancellables.executeOnMainActor {
        let filterSequence: AnyAsyncSequence<ResourcesFilter> =
          viewState
          .valuePublisher
          .map { filter in
            ResourcesFilter(
              sorting: .nameAlphabetically,
              text: filter.searchText,
              tags: [resourceTag.id]
            )
          }
          .removeDuplicates()
          .asAnyAsyncSequence()

        try await resources
          .filteredResourcesListPublisher(filterSequence.asPublisher())
          .asAnyAsyncSequence()
          .forLatest { resourcesList in
            viewState.withValue { state in
              state.resources = resourcesList
            }
          }
      }
    }
    else {
      viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.tags.explorer.title"),
          canCreateResources: false
        )
      )

      // refresh the list based on filters data
      cancellables.executeOnMainActor {
        let filterSequence: AnyAsyncSequence<String> =
          viewState
          .valuePublisher
          .map(\.searchText)
          .removeDuplicates()
          .asAnyAsyncSequence()

        try await resourceTags
          .filteredTagsList(filterSequence)
          .forLatest { tagsList in
            viewState.withValue { state in
              state.tags = tagsList
            }
          }
      }
    }

    // get the the user avatar image
    cancellables.executeOnMainActor {
      // ignore errors on getting avatar
      viewState.userAvatarImage =
        try? await accountSettings
        .currentAccountAvatarPublisher()
        .asAsyncValue()
    }

    @MainActor func refreshIfNeeded() async {
      do {
        try await sessionData
          .refreshIfNeeded()
      }
      catch {
        diagnostics.log(error)
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    @MainActor func presentTagContent(_ tag: ResourceTagDSV) {
      cancellables.executeOnMainActor {
        await navigation.push(
          TagsExplorerView.self,
          in: tag
        )
      }
    }

    @MainActor func presentResourceCreationFrom() {
      presentResourceEditingForm(for: .new(in: .none))
    }

    @MainActor func presentResourceEditingForm(
      for context: ResourceEditController.EditingContext
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          ResourceEditViewController.self,
          in: (
            context,
            completion: { _ in
              viewState.snackBarMessage = .info(
                .localized(
                  key: "resource.form.new.password.created"
                )
              )
            }
          )
        )
      }
    }

    @MainActor func presentResourceDetails(_ resourceID: Resource.ID) {
      cancellables.executeOnMainActor {
        await navigation.push(
          ResourceDetailsViewController.self,
          in: resourceID
        )
      }
    }

    @MainActor func presentResourceMenu(_ resourceID: Resource.ID) async {
      await navigation.presentSheetMenu(
        ResourceMenuViewController.self,
        in: (
          resourceID: resourceID,
          showEdit: { (resourceID: Resource.ID) in
            cancellables.executeOnMainActor {
              await navigation
                .dismiss(
                  SheetMenuViewController<ResourceMenuViewController>.self,
                  completion: {
                    presentResourceEditingForm(for: .existing(resourceID))
                  }
                )
            }
          },
          showDeleteAlert: { (resourceID: Resource.ID) in
            cancellables.executeOnMainActor {
              await navigation
                .dismiss(
                  SheetMenuViewController<ResourceMenuViewController>.self
                )
              await navigation.present(
                ResourceDeleteAlert.self,
                in: {
                  Task {
                    do {
                      try await resources
                        .deleteResource(resourceID)
                        .asAsyncValue()
                    }
                    catch {
                      viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
                    }
                  }
                }
              )
            }
          }
        )
      )
    }

    @MainActor func presentHomePresentationMenu() async {
      await navigation.presentSheet(
        HomePresentationMenuView.self,
        in: .foldersExplorer
      )
    }

    @MainActor func presentAccountMenu() async {
      do {
        let accountWithProfile: AccountWithProfile =
          try await accountSettings
          .currentAccountProfilePublisher()
          .asAsyncValue()

        await navigation.presentSheet(
          AccountMenuViewController.self,
          in: (
            accountWithProfile: accountWithProfile,
            navigation: navigation.asContextlessNavigation()
          )
        )
      }
      catch {
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    return Self(
      viewState: viewState,
      refreshIfNeeded: refreshIfNeeded,
      presentTagContent: presentTagContent(_:),
      presentResourceCreationFrom: presentResourceCreationFrom,
      presentResourceDetails: presentResourceDetails(_:),
      presentResourceMenu: presentResourceMenu(_:),
      presentHomePresentationMenu: presentHomePresentationMenu,
      presentAccountMenu: presentAccountMenu
    )
  }
}
