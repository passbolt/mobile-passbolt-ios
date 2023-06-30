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
import FeatureScopes
import OSFeatures
import Resources
import Session

internal final class ResourceTagsDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var name: String
    internal var favorite: Bool
    internal var tags: OrderedSet<ResourceTag>
  }

  internal nonisolated let viewState: ViewStateVariable<ViewState>

  private let resourceController: ResourceController

  private let navigationToSelf: NavigationToResourceTagsDetails

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(ResourceDetailsScope.self)

    self.navigationToSelf = try features.instance()

    self.resourceController = try features.instance()

    self.viewState = .init(
      initial: .init(
        name: .init(),
        favorite: false,
        tags: .init()
      )
    )
  }
}

extension ResourceTagsDetailsViewController {

  @Sendable internal func activate() async {
    await Diagnostics
      .logCatch(
        info: .message("Resource tags details updates broken!"),
        fallback: { _ in
          try? await self.navigationToSelf.revert()
        }
      ) {
        for try await resource in self.resourceController.state {
          self.update(resource)
        }
      }
  }

  internal func update(
    _ resource: Resource
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.name = resource.name
      state.favorite = resource.favorite
      state.tags = resource.tags
    }
  }
}
