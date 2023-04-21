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

internal struct ResourceLocationDetailsController {

  internal var viewState: MutableViewState<ViewState>
}

extension ResourceLocationDetailsController: ViewController {

  internal typealias Context = Resource.ID

  internal struct ViewState: Hashable {

    internal var resourceName: String
    internal var resourceLocation: FolderLocationTreeView.Node
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

extension ResourceLocationDetailsController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let resourceDetails: ResourceDetails = try features.instance(context: context)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        resourceName: .init(),
        resourceLocation: .root()
      )
    )

    asyncExecutor.schedule {
      do {
        let details: Resource! = try await resourceDetails.details()
        let resourceName = details.value(forField: "name")?.stringValue ?? ""
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
          child: .leaf(
            id: details.id,
            name: resourceName
          )
        )
        await viewState.update { viewState in
          viewState.resourceName = resourceName
          viewState.resourceLocation = path
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

  public mutating func usePassboltResourceLocationDetailsController() {
    self.use(
      .disposable(
        ResourceLocationDetailsController.self,
        load: ResourceLocationDetailsController.load(features:context:)
      ),
      in: ResourceDetailsScope.self
    )
  }
}
