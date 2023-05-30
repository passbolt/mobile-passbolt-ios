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
import SharedUIComponents

internal final class ResourceFolderMenuController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigation: DisplayNavigation

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigation = try features.instance()

    self.viewState = .init(
      initial: .init(
        folderName: context.folderName
      )
    )
  }
}

extension ResourceFolderMenuController {

  internal struct Context {

    internal var folderID: ResourceFolder.ID
    internal var folderName: String
  }

  internal struct ViewState: Hashable {

    internal var folderName: String
  }
}

extension ResourceFolderMenuController {

  internal final func openDetails() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      behavior: .reuse
    ) { [context, features, navigation] in
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
  }

  internal final func close() {
    self.asyncExecutor.schedule(.reuse) { @MainActor [navigation] in
      await navigation
        .dismissLegacySheet(ResourceFolderMenuView.self)
    }
  }
}
