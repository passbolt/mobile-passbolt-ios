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

internal struct ResourceFolderContentNodeController {

  @IID internal var id
  @NavigationNodeID public var nodeID
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourceFolderContentDisplayController
}

extension ResourceFolderContentNodeController: ViewNodeController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    // none means root
    internal var folderDetails: ResourceFolderDetails?
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
  }

  internal struct ViewState: Hashable {

    internal var folderName: DisplayableString
    internal var folderShared: Bool
    internal var snackBarMessage: SnackBarMessage?
  }

  internal struct ViewActions: ViewControllerActions {

    internal var closeExtension: () -> Void

    #if DEBUG
    internal static var placeholder: Self {
      .init(
        closeExtension: { unimplemented() }
      )
    }
    #endif
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder,
      searchController: .placeholder,
      contentController: .placeholder
    )
  }
  #endif
}

extension ResourceFolderContentNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let autofillContext: AutofillExtensionContext = features.instance()
    let resourceFolders: ResourceFolders = try await features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    let folderName: DisplayableString =
      context.folderDetails.map { .raw($0.name) }
      ?? .localized("home.presentation.mode.folders.explorer.title")

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        folderName: folderName,
        folderShared: context.folderDetails?.shared ?? false,
        snackBarMessage: .none
      )
    )

    let viewState: ViewStateBinding<ViewState> = .init(stateSource: state)

    let searchController: ResourceSearchDisplayController = try await features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    let contentController: ResourceFolderContentDisplayController = try await features.instance(
      context: .init(
        folderName: folderName,
        filter: searchController
          .searchText
          .convert { (text: String) -> ResourceFoldersFilter in
            ResourceFoldersFilter(
              sorting: .nameAlphabetically,
              text: text,
              folderID: context.folderDetails?.folderID,
              flattenContent: !text.isEmpty,
              permissions: []
            )
          },
        suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
          requestedServiceIdentifiers.matches(resource)
        },
        createFolder: .none,
        createResource: context.folderDetails?.permissionType != .read // root or owned / write
          ? .none
          : createResource,
        selectFolder: selectFolder(_:),
        selectResource: selectResource(_:),
        openResourceMenu: .none,
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    @Sendable nonisolated func createResource() {
      asyncExecutor.schedule(.reuse) {
        await navigationTree
          .push(
            ResourceEditViewController.self,
            context: (
              editing: .new(
                in: context.folderDetails?.folderID,
                url: requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
              ),
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
              .error("Missing resource password in secret.")
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

    @Sendable nonisolated func selectFolder(
      _ resourceFolderID: ResourceFolder.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          let folderDetails: ResourceFolderDetails = try await resourceFolders.details(resourceFolderID)

          let nodeController: ResourceFolderContentNodeController =
            try await features
            .instance(
              of: ResourceFolderContentNodeController.self,
              context: .init(folderDetails: folderDetails)
            )
          navigationTree
            .push(
              ResourceFolderContentNodeView.self,
              controller: nodeController
            )
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

    nonisolated func closeExtension() {
      asyncExecutor.schedule(.reuse) {
        await autofillContext.cancelAndCloseExtension()
      }
    }

    return .init(
      viewState: viewState,
      viewActions: .init(
        closeExtension: closeExtension
      ),
      searchController: searchController,
      contentController: contentController
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltFolderContentNodeController() {
    self.use(
      .disposable(
        ResourceFolderContentNodeController.self,
        load: ResourceFolderContentNodeController.load(features:context:)
      )
    )
  }
}
