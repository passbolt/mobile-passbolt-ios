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
import OSFeatures
import Resources
import Users

internal final class ResourceFolderLocationDetailsController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal init(
    context: ResourceFolder.ID,
    features: Features
  ) throws {

    let resourceFolderController: ResourceFolderController = try features.instance()

    self.viewState = .init(
      initial: .init(
        folderName: "",
        folderLocation: .root(),
        folderShared: false
      ),
      updateFrom: resourceFolderController.state,
			update: { updateView, update in
        let resourceFolder: ResourceFolder = try update.value
        var path: FolderLocationTreeView.Node = resourceFolder.path.reduce(
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
        if let id: ResourceFolder.ID = resourceFolder.id {
          path.append(
            child: .node(
              id: id,
              name: resourceFolder.name,
              shared: resourceFolder.shared
            )
          )
        }  // else NOP
        await updateView { (state: inout ViewState) in
          state.folderName = resourceFolder.name
          state.folderLocation = path
          state.folderShared = resourceFolder.shared
        }
      }
    )
  }
}

extension ResourceFolderLocationDetailsController {

  internal struct ViewState: Equatable {

    internal var folderName: String
    internal var folderLocation: FolderLocationTreeView.Node
    internal var folderShared: Bool
  }
}
