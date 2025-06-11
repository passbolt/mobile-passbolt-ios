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
import FeatureScopes
import Metadata
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceFolderContentNodeController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal var searchController: ResourceSearchDisplayController!  // lazy?
  internal var contentController: ResourceFolderContentDisplayController!  // lazy?

  private let navigationTree: NavigationTree
  private let autofillContext: AutofillExtensionContext
  private let resourceFolders: ResourceFolders

  private let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier>
  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.navigationTree = features.instance()
    self.autofillContext = features.instance()
    self.resourceFolders = try features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> = self.autofillContext
      .requestedServiceIdentifiers()
    self.requestedServiceIdentifiers = requestedServiceIdentifiers

    let folderName: DisplayableString =
      context.folderDetails.map { .raw($0.name) }
      ?? .localized("home.presentation.mode.folders.explorer.title")

    let viewState: ViewStateSource<ViewState> = .init(
      initial: .init(
        folderName: folderName,
        folderShared: context.folderDetails?.shared ?? false
      )
    )
    self.viewState = viewState

    self.searchController = try features.instance(
      context: .init(
        nodeID: context.nodeID,
        searchPrompt: context.searchPrompt
      )
    )

    self.contentController = try features.instance(
      context: .init(
        folderName: folderName,
        filter: ComputedVariable(
          transformed: searchController
            .searchText,
          { update -> ResourceFoldersFilter in
            let text: String = try update.value
            return ResourceFoldersFilter(
              sorting: .nameAlphabetically,
              text: text,
              folderID: context.folderDetails?.id,
              flattenContent: !text.isEmpty,
              permissions: []
            )
          }
        )
        .asAnyUpdatable(),
        suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
          requestedServiceIdentifiers.matches(resource)
        },
        createFolder: .none,
        createResource: context.folderDetails?.permission != .read  // root or owned / write
          ? self.createResource
          : .none,
        selectFolder: self.selectFolder(_:),
        selectResource: self.selectResource(_:),
        openResourceMenu: .none
      )
    )
  }
}

extension ResourceFolderContentNodeController {

  internal struct Context {

    internal var nodeID: ViewNodeID
    // none means root
    internal var folderDetails: ResourceFolder?
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
  }

  internal struct ViewState: Equatable {

    internal var folderName: DisplayableString
    internal var folderShared: Bool
  }
}

extension ResourceFolderContentNodeController {

  internal final func createResource() async throws {
    let resourceEditPreparation: ResourceEditPreparation = try self.features.instance()
    let metadataSettingsService: MetadataSettingsService = try self.features.instance()

    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(
      metadataSettingsService.typesSettings().defaultResourceTypeSlug,
      self.context.folderDetails?.id,
      requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
    )
    try self.navigationTree.push(
      ResourceEditView.self,
      controller: .init(
        context: .init(
          editingContext: editingContext,
          success: { [autofillContext] resource in
            if let password: String = resource.firstPasswordString {
              await autofillContext
                .completeWithCredential(
                  AutofillExtensionContext.Credential(
                    user: resource.meta.username.stringValue ?? "",
                    password: password
                  )
                )
            }
            else {
              ResourceSecretInvalid
                .error("Missing resource password in secret.")
                .consume()
            }
          }
        ),
        features: self.features
      )
    )
  }

  @Sendable internal func selectResource(
    _ resourceID: Resource.ID
  ) async throws {
    let features: Features = try self.features.branch(
      scope: ResourceScope.self,
      context: resourceID
    )
    let resourceController: ResourceController = try features.instance()
    try await resourceController.fetchSecretIfNeeded(force: true)
    let resource: Resource = try await resourceController.state.value

    guard let password: String = resource.firstPasswordString
    else {
      throw
        ResourceSecretInvalid
        .error("Missing resource password in secret.")
    }
    self.autofillContext
      .completeWithCredential(
        AutofillExtensionContext.Credential(
          user: resource.meta.username.stringValue ?? "",
          password: password
        )
      )
  }

  internal final func selectFolder(
    _ resourceFolderID: ResourceFolder.ID
  ) async throws {
    let folderDetails: ResourceFolder = try await self.resourceFolders.details(resourceFolderID)

    let nodeController: ResourceFolderContentNodeController =
      try self.features
      .instance(
        of: ResourceFolderContentNodeController.self,
        context: .init(
          nodeID: self.context.nodeID,
          folderDetails: folderDetails
        )
      )
    self.navigationTree
      .push(
        ResourceFolderContentNodeView.self,
        controller: nodeController
      )
  }

  internal func closeExtension() {
    self.autofillContext.cancelAndCloseExtension()
  }
}
