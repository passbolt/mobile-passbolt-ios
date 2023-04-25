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

internal struct ResourceDetailsTagsListController {

  internal var viewState: MutableViewState<ViewState>
}

extension ResourceDetailsTagsListController {

  internal struct ViewState: Hashable {

    internal var resourceName: String
    internal var resourceFavorite: Bool
    internal var tags: OrderedSet<ResourceTag>
  }
}

extension ResourceDetailsTagsListController: ViewController {

  internal typealias Context = Resource.ID

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    .init(
      viewState: .placeholder()
    )
  }
  #endif
}

extension ResourceDetailsTagsListController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Resource.ID
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigation: DisplayNavigation = try features.instance()
    let resourceDetails: ResourceDetails = try features.instance(context: context)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        resourceName: .init(),
        resourceFavorite: .init(),
        tags: .init()
      )
    )

    asyncExecutor.schedule { @MainActor in
      do {
        let resourceDetails: Resource = try await resourceDetails.details()
        viewState.update { (state: inout ViewState) in
          state.resourceName = resourceDetails.value(forField: "name").stringValue ?? ""
          state.resourceFavorite = resourceDetails.favorite
          state.tags = resourceDetails.tags
        }
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    return Self(
      viewState: viewState
    )
  }
}
extension FeaturesRegistry {

  internal mutating func useLiveResourceDetailsTagsListController() {
    self.use(
      .disposable(
        ResourceDetailsTagsListController.self,
        load: ResourceDetailsTagsListController.load(features:context:)
      ),
      in: ResourceDetailsScope.self
    )
  }
}
