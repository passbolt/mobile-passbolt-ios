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

// MARK: - Interface

internal struct ResourceFolderLocationDetailsController {

  internal var viewState: MutableViewState<ViewState>
}

extension ResourceFolderLocationDetailsController: ViewController {

  internal typealias Context = ResourceFolder.ID

  internal struct ViewState: Hashable {

    internal var folderName: String
    internal var folderLocation: FolderLocationTreeView.Node
    internal var folderShared: Bool
  }

  #if DEBUG
  static var placeholder: Self {
    .init(
      viewState: .placeholder()
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderLocationDetailsController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let executor: AsyncExecutor = try features.instance()
    let folderDetails: ResourceFolderDetails = try features.instance(context: context)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        folderName: "",
        folderLocation: .root(),
        folderShared: false
      )
    )

    executor.schedule {
      do {
        let details: ResourceFolderDetailsDSV = try await folderDetails.details()
        var path: FolderLocationTreeView.Node = details.path.reduce(
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
          child: .node(
            id: details.id,
            name: details.name,
            shared: details.shared
          )
        )
        await viewState.update { (state: inout ViewState) in
          state.folderName = details.name
          state.folderLocation = path
          state.folderShared = details.shared
        }
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    return .init(
      viewState: viewState
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourceFolderLocationDetailsController() {
    self.use(
      .disposable(
        ResourceFolderLocationDetailsController.self,
        load: ResourceFolderLocationDetailsController.load(features:context:)
      ),
      in: ResourceFolderDetailsScope.self
    )
  }
}
