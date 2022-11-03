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
import SharedUIComponents

// MARK: - Interface

internal struct ResourceFolderMenuController {

  @IID internal var id
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension ResourceFolderMenuController: ViewController {

  internal struct Context: LoadableFeatureContext, Hashable {

    internal var folderID: ResourceFolder.ID
    internal var folderName: String
  }

  internal struct ViewState: Hashable {

    internal var folderName: String
  }

  internal struct ViewActions: ViewControllerActions {

    internal var openDetails: () -> Void
    internal var close: () -> Void

    #if DEBUG
    static var placeholder: Self {
      .init(
        openDetails: unimplemented(),
        close: unimplemented()
      )
    }
    #endif
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderMenuController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self)
      .detach()
    let navigation: DisplayNavigation = try await features.instance()

    nonisolated func openDetails() {
      asyncExecutor.schedule(.reuse) { @MainActor in
        do {
          await navigation
            .dismissLegacySheet(ResourceFolderMenuView.self)
          try await navigation
            .push(
              ResourceFolderDetailsView.self,
              controller:
                features
                .instance(
                  context: context.folderID
                )
            )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    nonisolated func close() {
      asyncExecutor.schedule(.reuse) { @MainActor in
        await navigation
          .dismissLegacySheet(ResourceFolderMenuView.self)
      }
    }

    return .init(
      viewState: .init(
        initial: .init(
          folderName: context.folderName
        )
      ),
      viewActions: .init(
        openDetails: openDetails,
        close: close
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderMenuController() {
    self.use(
      .disposable(
        ResourceFolderMenuController.self,
        load: ResourceFolderMenuController.load(features:context:)
      )
    )
  }
}
