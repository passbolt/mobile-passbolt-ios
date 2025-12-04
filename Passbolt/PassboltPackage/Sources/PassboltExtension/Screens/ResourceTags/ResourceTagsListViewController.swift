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
import Metadata
import OSFeatures
import Resources
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourceTagsListViewController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
  internal var searchController: ResourceSearchDisplayController!
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
  internal var contentController: ResourceTagsListDisplayController!

  private let autofillContext: AutofillExtensionContext
  private let resourceTags: ResourceTags
  private let navigationToHomePresentationMenu: NavigationToHomePresentationMenu

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.autofillContext = features.instance()
    self.resourceTags = try features.instance()
    self.navigationToHomePresentationMenu = try features.instance()

    let session: Session = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName
      )
    )

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        onPresentationMenuTap: {
          try await self.navigationToHomePresentationMenu.perform()
        },
        onAvatarTap: {
          await session.close(.none)
        }
      )
    )

    self.contentController = try features.instance(
      context: .init(
        filter: self.searchController.searchText.asAnyUpdatable(),
        selectTag: { [weak self] in try await self?.selectResourceTag($0) }
      )
    )
  }
}

extension ResourceTagsListViewController {

  internal struct Context {

    internal var title: DisplayableString = .localized(key: "home.presentation.mode.tags.explorer.title")
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var titleIconName: ImageNameConstant = .tag
  }

  internal struct ViewState: Equatable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
  }
}

extension ResourceTagsListViewController {

  internal final func selectResourceTag(
    _ resourceTagID: ResourceTag.ID
  ) async throws {
    let tagDetails: ResourceTag = try await self.resourceTags.details(resourceTagID)
    let navigationToResourcesList: NavigationToResourcesList = try features.instance()
    try await navigationToResourcesList.perform(
      context: .init(
        title: .raw(tagDetails.slug.rawValue),
        titleIconName: .tag,
        baseFilter: .init(
          sorting: .nameAlphabetically,
          tags: [resourceTagID]
        ),
        appModeContext: .createExtensionContext(using: features)
      )
    )
  }

  internal final func closeExtension() {
    self.autofillContext.cancelAndCloseExtension()
  }
}

extension ResourcesListViewController.Callbacks {

  @MainActor
  static func createExtensionContext(using features: Features) -> Self {
    let autofillContext: AutofillExtensionContext = features.instance()
    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    @Sendable @MainActor func selectResource(
      _ resourceID: Resource.ID
    ) async throws {
      let features: Features = try features.branch(
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
      autofillContext
        .completeWithCredential(
          AutofillExtensionContext.Credential(
            user: resource.meta.username.stringValue ?? "",
            password: password
          )
        )
    }

    return
      .init(
        suggestionFilter: { requestedServiceIdentifiers.matches($0) },
        onClose: {
          autofillContext.cancelAndCloseExtension()
        },
        onPresentationMenuTap: {
          let navigationToHomePresentationMenu: NavigationToHomePresentationMenu = try features.instance()
          await navigationToHomePresentationMenu
            .performCatching()
        },
        onAvatarTap: {
          let session: Session = try features.instance()
          await session.close(.none)
        },
        createResource: {
          let resourceEditPreparation: ResourceEditPreparation = try features.instance()
          let metadataSettingsService: MetadataSettingsService = try features.instance()

          let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(
            metadataSettingsService.typesSettings().defaultResourceTypeSlug,
            .none,
            requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
          )
          let navigationToResourceEdit: NavigationToResourceEdit = try features.instance()

          await navigationToResourceEdit
            .performCatching(
              context: .init(
                editingContext: editingContext,
                success: { (resource: Resource) in
                  guard let resourceId: Resource.ID = resource.id
                  else {
                    return
                  }
                  await consumingErrors {
                    try await selectResource(resourceId)
                  }
                }
              )
            )
        },
        selectResource: selectResource(_:)
      )
  }
}
