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
import Display
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import UIComponents

@MainActor
internal struct FoldersExplorerController {

  internal let viewState: ObservableValue<ViewState>
  internal var refreshIfNeeded: @MainActor () async -> Void
  internal var presentFolderContent: @MainActor (ResourceFolderListItemDSV) -> Void
  internal var presentAddNew: @MainActor (ResourceFolder.ID?) -> Void
  internal var presentResourceDetails: @MainActor (Resource.ID) -> Void
  internal var presentResourceMenu: @MainActor (Resource.ID) -> Void
  internal var presentHomePresentationMenu: @MainActor () -> Void
  internal var presentAccountMenu: @MainActor () -> Void
  internal var presentResourceFolderMenu: () -> Void
}

extension FoldersExplorerController: ComponentController {

  internal typealias ControlledView = FoldersExplorerView
  internal typealias Context = ResourceFolderListItemDSV?

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features = features

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()

    let navigation: DisplayNavigation = try features.instance()
    let currentAccount: Account = try features.sessionAccount()
    let accountDetails: AccountDetails = try features.instance(context: currentAccount)
    let resources: Resources = try features.instance()
    let sessionData: SessionData = try features.instance()
    let folders: ResourceFolders = try features.instance()

    let viewState: ObservableValue<ViewState>

    if let folder: ResourceFolderListItemDSV = context {
      viewState = .init(
        initial: .init(
          title: .raw(folder.name),
          folderID: folder.id,
          folderShared: folder.shared,
          canCreateResources: folder.permissionType != .read  // write / owned
        )
      )
    }
    else {
      viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.folders.explorer.title"),
          folderShared: false,
          canCreateResources: true
        )
      )
    }

    // get the the user avatar image
    cancellables.executeOnMainActor {
      // ignore errors on getting avatar
      viewState.userAvatarImage =
        try? await accountDetails
        .avatarImage()
    }

    // refresh the list based on filters data
    cancellables.executeOnMainActor {
      do {
        try await combineLatest(
          sessionData.updatesSequence,
          viewState.asAnyAsyncSequence()
        )
        .map { (_, state: ViewState) -> ResourceFoldersFilter in
          ResourceFoldersFilter(
            sorting: .nameAlphabetically,
            text: state.searchText,
            folderID: context?.id,
            flattenContent: !state.searchText.isEmpty,
            permissions: .init()
          )
        }
        .map { filter in
          try await folders
            .filteredFolderContent(filter)
        }
        .forEach { content in
          await viewState.withValue { state in
            state.directFolders = content
              .subfolders
              .filter { $0.parentFolderID == context?.id }
            state.nestedFolders = content
              .subfolders
              .filter { $0.parentFolderID != context?.id }
            state.directResources = content
              .resources
              .filter { $0.parentFolderID == context?.id }
            state.nestedResources = content
              .resources
              .filter { $0.parentFolderID != context?.id }
          }
        }
      }
      catch {
        diagnostics
          .log(
            error: error,
            info: .message("Folders explorer updates broken")
          )
      }
    }

    @MainActor func refreshIfNeeded() async {
      // TODO: [MOB-255] check if current folder was not deleted
      do {
        try await sessionData
          .refreshIfNeeded()
      }
      catch {
        diagnostics.log(error: error)
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    @MainActor func presentFolderContent(_ folder: ResourceFolderListItemDSV) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: FoldersExplorerView.self,
          context: folder
        )
      }
    }

    @MainActor func presentAddNew(
      folderID: ResourceFolder.ID?
    ) {
      #warning("MOB-616 check if can create folder?")
      cancellables.executeOnMainActor {
        do {
          try await navigation.presentSheet(
            ResourcesListCreateMenuView.self,
            controller:
              features
              .instance(
                of: ResourcesListCreateMenuController.self,
                context: .init(
                  enclosingFolderID: folderID
                )
              )
          )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    @MainActor func presentResourceShareForm(
      for resourceID: Resource.ID
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: ResourcePermissionEditListView.self,
          context: resourceID
        )
      }
    }

    @MainActor func presentResourceEditingForm(
      for context: ResourceEditController.EditingContext
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: ResourceEditViewController.self,
          context: (
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
          legacy: ResourceDetailsViewController.self,
          context: resourceID
        )
      }
    }

    @MainActor func presentResourceMenu(_ resourceID: Resource.ID) {
      cancellables.executeOnMainActor {
        await navigation.presentSheetMenu(
          ResourceMenuViewController.self,
          in: (
            resourceID: resourceID,
            showShare: { (resourceID: Resource.ID) in
              cancellables.executeOnMainActor {
                await navigation
                  .dismiss(
                    SheetMenuViewController<ResourceMenuViewController>.self
                  )
                presentResourceShareForm(for: resourceID)
              }
            },
            showEdit: { (resourceID: Resource.ID) in
              cancellables.executeOnMainActor {
                await navigation
                  .dismiss(
                    SheetMenuViewController<ResourceMenuViewController>.self
                  )
                presentResourceEditingForm(for: .existing(resourceID))
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
    }

    @MainActor func presentHomePresentationMenu() {
      cancellables.executeOnMainActor {
        await navigation.presentSheet(
          HomePresentationMenuView.self,
          in: .foldersExplorer
        )
      }
    }

    @MainActor func presentAccountMenu() {
      asyncExecutor.schedule(.reuse) {
        await diagnostics
          .withLogCatch(
            info: .message(
              "Navigation to account menu failed!"
            )
          ) {
            try await navigationToAccountMenu.perform()
          }
      }
    }

    nonisolated func presentResourceFolderMenu() {
      cancellables.executeOnMainActor {
        guard let folderItem: ResourceFolderListItemDSV = context
        else { return assertionFailure("Can't show folder menu for root") }
        do {
          try await navigation.presentSheet(
            ResourceFolderMenuView.self,
            controller:
              features
              .instance(
                of: ResourceFolderMenuController.self,
                context: .init(
                  folderID: folderItem.id,
                  folderName: folderItem.name
                )
              )
          )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    return Self(
      viewState: viewState,
      refreshIfNeeded: refreshIfNeeded,
      presentFolderContent: presentFolderContent(_:),
      presentAddNew: presentAddNew,
      presentResourceDetails: presentResourceDetails(_:),
      presentResourceMenu: presentResourceMenu(_:),
      presentHomePresentationMenu: presentHomePresentationMenu,
      presentAccountMenu: presentAccountMenu,
      presentResourceFolderMenu: presentResourceFolderMenu
    )
  }
}
