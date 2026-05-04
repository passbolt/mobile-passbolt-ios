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
import Users

public final class ResourcesListViewController: ViewController {

  public nonisolated let viewState: ViewStateSource<ViewState>
  internal let searchController: ResourceSearchDisplayController
  internal let contentController: ResourcesListDisplayController

  private let context: Context
  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    let viewState: ViewStateSource<ViewState> = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        showBackButton: context.callbacks.backAction != nil,
        showCloseButton: context.callbacks.onClose != nil
      )
    )
    self.viewState = viewState

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        onPresentationMenuTap: context.callbacks.onPresentationMenuTap,
        onAvatarTap: context.callbacks.onAvatarTap
      )
    )

    self.contentController = try features.instance(
      context: .init(
        baseFilter: context.baseFilter,
        filterTextSource: self.searchController
          .searchText.asAnyUpdatable(),
        suggestionFilter: context.callbacks.suggestionFilter ?? { _ in false },
        createResource: context.callbacks.createResource,
        selectResource: context.callbacks.selectResource,
        resourceMenuAction: context.callbacks.contextualMenuAction
      )
    )
  }
}

extension ResourcesListViewController {

  public struct Context: Sendable {

    internal let title: DisplayableString
    internal let titleIconName: ImageNameConstant
    internal let searchPrompt: DisplayableString
    internal let baseFilter: ResourcesFilter
    internal let callbacks: Callbacks

    public init(
      title: DisplayableString,
      titleIconName: ImageNameConstant,
      searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder"),
      baseFilter: ResourcesFilter,
      appModeContext: Callbacks
    ) {
      self.title = title
      self.titleIconName = titleIconName
      self.searchPrompt = searchPrompt
      self.baseFilter = baseFilter
      self.callbacks = appModeContext
    }
  }

  public struct Callbacks: Sendable {
    internal let suggestionFilter: (@Sendable (ResourceListItemDSV) -> Bool)?
    internal let onClose: (@Sendable () async -> Void)?
    internal let onPresentationMenuTap: @Sendable () async throws -> Void
    internal let onAvatarTap: @Sendable () async throws -> Void
    internal let createResource: @Sendable () async throws -> Void
    internal let selectResource: @Sendable (Resource.ID) async throws -> Void
    internal let contextualMenuAction: (@Sendable (Resource.ID) async throws -> Void)?
    internal let backAction: (@Sendable () async throws -> Void)?

    public init(
      suggestionFilter: (@Sendable (ResourceListItemDSV) -> Bool)? = nil,
      onClose: (@Sendable () async -> Void)? = nil,
      onPresentationMenuTap: @Sendable @escaping () async throws -> Void,
      onAvatarTap: @Sendable @escaping () async throws -> Void,
      createResource: @Sendable @escaping () async throws -> Void,
      selectResource: @Sendable @escaping (Resource.ID) async throws -> Void,
      contextualMenuAction: (@Sendable (Resource.ID) async throws -> Void)? = .none,
      backAction: (@Sendable () async throws -> Void)?
    ) {
      self.suggestionFilter = suggestionFilter
      self.onClose = onClose
      self.onPresentationMenuTap = onPresentationMenuTap
      self.onAvatarTap = onAvatarTap
      self.createResource = createResource
      self.selectResource = selectResource
      self.contextualMenuAction = contextualMenuAction
      self.backAction = backAction
    }
  }

  public struct ViewState: Equatable, Sendable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var showBackButton: Bool
    internal var showCloseButton: Bool
  }
}

extension ResourcesListViewController {

  internal final func closeExtension() async {
    await self.context.callbacks.onClose?()
  }
}
