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

internal final class ResourcesListNodeController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourcesListDisplayController!  // lazy init?

  private let navigationTree: NavigationTree
  private let autofillContext: AutofillExtensionContext

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

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()
    self.requestedServiceIdentifiers = requestedServiceIdentifiers

    let viewState: ViewStateSource<ViewState> = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName
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
        baseFilter: context.baseFilter,
        filterTextSource: self.searchController
          .searchText.asAnyUpdatable(),
        suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
          requestedServiceIdentifiers.matches(resource)
        },
        createResource: self.createResource,
        selectResource: self.selectResource(_:)
      )
    )
  }
}

extension ResourcesListNodeController {

  internal struct Context {

    internal var nodeID: ViewNodeID
    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var baseFilter: ResourcesFilter
  }

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
  }
}

extension ResourcesListNodeController {

  internal final func createResource() async throws {
    let resourceEditPreparation: ResourceEditPreparation = try self.features.instance()
    let metadataSettingsService: MetadataSettingsService = try self.features.instance()
    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(
      metadataSettingsService.typesSettings().defaultResourceTypeSlug,
      .none,
      self.requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
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
                .log()
            }
          }
        ),
        features: self.features
      )
    )
  }

  nonisolated internal final func selectResource(
    _ resourceID: Resource.ID
  ) async throws {
    let features: Features = try await self.features.branch(
      scope: ResourceScope.self,
      context: resourceID
    )
    let resourceController: ResourceController = try await features.instance()
    try await resourceController.fetchSecretIfNeeded(force: true)
    let resource: Resource = try await resourceController.state.value

    guard let password: String = resource.firstPasswordString
    else {
      throw
        ResourceSecretInvalid
        .error("Missing resource password in secret.")
    }
    await self.autofillContext
      .completeWithCredential(
        AutofillExtensionContext.Credential(
          user: resource.meta.username.stringValue ?? "",
          password: password
        )
      )
  }

  internal final func closeExtension() {
    self.autofillContext.cancelAndCloseExtension()
  }
}
