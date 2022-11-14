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
import Users

// MARK: - Interface

internal struct ResourceFolderLocationDetailsController {

  internal var viewState: ViewStateBinding<ViewState>
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
      viewState: .placeholder
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderLocationDetailsController {

  fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let folderDetails: ResourceFolderDetails = try await features.instance(context: context)

    let details: ResourceFolderDetailsDSV = try await folderDetails.details()

    let viewState: ViewStateBinding<ViewState> = .init(
      initial: .init(
        folderName: details.name,
        folderLocation: {
          var location: FolderLocationTreeView.Node = details.location.reduce(
            into: FolderLocationTreeView.Node.root()
          ) { (partialResult: inout FolderLocationTreeView.Node, item: ResourceFolderLocationItemDSV) in
            partialResult.append(
              child: .node(
                id: item.folderID,
                name: item.folderName,
                shared: item.folderShared
              )
            )
          }
          location.append(
            child: .node(
              id: details.id,
              name: details.name,
              shared: details.shared
            )
          )
          return location
        }(),
        folderShared: details.shared
      )
    )

    return .init(
      viewState: viewState
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderLocationDetailsController() {
    self.use(
      .disposable(
        ResourceFolderLocationDetailsController.self,
        load: ResourceFolderLocationDetailsController.load(features:context:)
      )
    )
  }
}
