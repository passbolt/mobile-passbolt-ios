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

import Display
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal struct HomeNavigationNodeController {

  internal var viewState: DisplayViewState<ViewState>
  internal var activate: @Sendable () async -> Void
  internal var showPresentationMenu: () -> Void
  internal var signOut: () -> Void
  internal var closeExtension: () -> Void
}

extension HomeNavigationNodeController: ContextlessNavigationNodeController {

  internal struct ViewState: Hashable {

    @StateBinding internal var mode: HomePresentationMode
    internal var modeContent: AnyDisplayController
    internal var accountAvatar: Data?
    internal var searchText: String
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      activate: { unimplemented() },
      showPresentationMenu: { unimplemented() },
      signOut: { unimplemented() },
      closeExtension: { unimplemented() }
    )
  }
  #endif
}

extension HomeNavigationNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let autofillContext: AutofillExtensionContext = features.instance()
    let session: Session = try await features.instance()
    let currentAccount: Account = try await session.currentAccount()
    let accountDetails: AccountDetails = try await features.instance(context: currentAccount)
    let homePresentation: HomePresentation = try await features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    let state: StateBinding<ViewState> = try await .variable(
      initial: .init(
        mode: homePresentation.currentMode,
        modeContent: .empty(),
        accountAvatar: .none,
        searchText: "",
        snackBarMessage: .none
      )
    )
    state.bind(\.$mode)

    let viewState: DisplayViewState<ViewState> = .init(stateSource: state)

    homePresentation
      .currentMode
      .sink { (mode: HomePresentationMode) in
        asyncExecutor.schedule(.replace) {
          await state.set(
            \.modeContent,
            to: modeContent(for: mode)
          )
        }
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func modeContent(
      for mode: HomePresentationMode
    ) async -> AnyDisplayController {
      do {
        switch mode {
        case .plainResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourcesListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourcesFilter(
                        sorting: .nameAlphabetically,
                        text: state.searchText,
                        favoriteOnly: false,
                        permissions: [],
                        tags: [],
                        userGroups: [],
                        folders: .none
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .modifiedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourcesListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourcesFilter(
                        sorting: .modifiedRecently,
                        text: state.searchText,
                        favoriteOnly: false,
                        permissions: [],
                        tags: [],
                        userGroups: [],
                        folders: .none
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .favoriteResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourcesListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourcesFilter(
                        sorting: .nameAlphabetically,
                        text: state.searchText,
                        favoriteOnly: true,
                        permissions: [],
                        tags: [],
                        userGroups: [],
                        folders: .none
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .sharedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourcesListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourcesFilter(
                        sorting: .nameAlphabetically,
                        text: state.searchText,
                        favoriteOnly: false,
                        permissions: [.read, .write],
                        tags: [],
                        userGroups: [],
                        folders: .none
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .ownedResourcesList:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourcesListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourcesFilter(
                        sorting: .nameAlphabetically,
                        text: state.searchText,
                        favoriteOnly: false,
                        permissions: [.owner],
                        tags: [],
                        userGroups: [],
                        folders: .none
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .tagsExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceTagsListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      state.searchText
                    },
                  selectTag: selectResourceTag(_:),
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .resourceUserGroupsExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceUserGroupsListDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      UserGroupsFilter(
                        userID: currentAccount.userID,
                        text: state.searchText
                      )
                    },
                  selectGroup: selectUserGroup(_:),
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )

        case .foldersExplorer:
          return try await AnyDisplayController(
            erasing:
              features
              .instance(
                of: ResourceFolderContentDisplayController.self,
                context: .init(
                  filter:
                    state
                    .scopeView { (state: ViewState) in
                      ResourceFoldersFilter(
                        sorting: .nameAlphabetically,
                        text: state.searchText,
                        folderID: .none,
                        flattenContent: !state.searchText.isEmpty,
                        permissions: []
                      )
                    },
                  suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
                    requestedServiceIdentifiers.matches(resource)
                  },
                  createResource: createResource,
                  selectFolder: selectResourceFolder(_:),
                  selectResource: selectResource(_:),
                  openResourceMenu: .none,
                  showMessage: { (message: SnackBarMessage?) in
                    state.set(\.snackBarMessage, to: message)
                  }
                )
              )
          )
        }
      }
      catch {
        error
          .asTheError()
          .asFatalError(message: "Failed to prepare home screen.")
      }
    }

    @Sendable nonisolated func activate() async {
      asyncExecutor.schedule(.reuse) {
        do {
          let avatar: Data? = try await accountDetails.avatarImage()
          state.mutate { state in
            state.accountAvatar = avatar
          }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to load account avatar image, using placeholder."
            )
          )
        }
      }
    }

    @Sendable nonisolated func createResource() {
      asyncExecutor.schedule(.reuse) {
        await navigationTree
          .push(
            ResourceEditViewController.self,
            context: (
              editing: .new(in: .none, url: requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }),
              completion: { resourceID in
                selectResource(resourceID)
              }
            ),
            using: features
          )
      }
    }

    @Sendable nonisolated func selectResource(
      _ resourceID: Resource.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
          let resource: ResourceDetailsDSV = try await resourceDetails.details()
          let secret: ResourceSecret = try await resourceDetails.secret()

          guard let password: String = secret.password
          else {
            throw
              ResourceSecretInvalid
              .error("Missing resource password ine secret.")
          }
          await autofillContext
            .completeWithCredential(
              AutofillExtensionContext.Credential(
                user: resource.username ?? "",
                password: password
              )
            )
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle resource selection."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    @Sendable nonisolated func selectResourceFolder(
      _ resourceFolderID: ResourceFolder.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          #warning("TODO: [MOB-477] navigate")
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle resource folder selection."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    @Sendable nonisolated func selectResourceTag(
      _ resourceTagID: ResourceTag.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          #warning("TODO: [MOB-477] navigate")
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle resource tag selection."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    @Sendable nonisolated func selectUserGroup(
      _ userGroupID: UserGroup.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          #warning("TODO: [MOB-477] navigate")
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle user group selection."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    nonisolated func showPresentationMenu() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationTree.present(
            HomePresentationMenuNodeView.self,
            controller: features.instance()
          )
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to open home presentation menu."
            )
          )
          state.set(\.snackBarMessage, to: .error(error))
        }
      }
    }

    nonisolated func signOut() {
      asyncExecutor.schedule(.reuse) {
        await session.close(.none)
      }
    }

    nonisolated func closeExtension() {
      asyncExecutor.schedule(.reuse) {
        await autofillContext.cancelAndCloseExtension()
      }
    }

    return .init(
      viewState: viewState,
      activate: activate,
      showPresentationMenu: showPresentationMenu,
      signOut: signOut,
      closeExtension: closeExtension
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltHomeNavigationNodeController() {
    self.use(
      .disposable(
        HomeNavigationNodeController.self,
        load: HomeNavigationNodeController.load(features:)
      )
    )
  }
}
