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
import OSFeatures
import Resources
import Users

internal final class ResourceLocationDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var name: String
    internal var favorite: Bool
    internal var location: FolderLocationTreeView.Node
  }

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let navigationToSelf: NavigationToResourceLocationDetails

  private let resourceController: ResourceController

  private let diagnostics: OSDiagnostics

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(ResourceDetailsScope.self)

    self.diagnostics = features.instance()

    self.navigationToSelf = try features.instance()

    self.resourceController = try features.instance()

    self.viewState = .init(
      initial: .init(
        name: .init(),
        favorite: false,
        location: .root()
      )
    )
  }
}

extension ResourceLocationDetailsViewController {

  @Sendable internal func activate() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Resource location details updates broken!"),
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
    let resourceName: String = resource.name
    var path: FolderLocationTreeView.Node = resource.path.reduce(
      into: FolderLocationTreeView.Node.root()
    ) { (partialResult: inout FolderLocationTreeView.Node, item: ResourceFolderPathItem) in
      partialResult.append(
        child: .node(
          id: item.id,
          name: item.name,
          shared: item.shared
        )
      )
    }
    path.append(
      child: .leaf(
        id: resource.id,
        name: resourceName
      )
    )

    self.viewState.update { (state: inout ViewState) in
      state.name = resourceName
      state.favorite = resource.favorite
      state.location = path
    }
  }
}
