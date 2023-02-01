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

// MARK: - Interface

internal struct ResourcesListCreateMenuController {

  internal var viewState: ViewStateBinding<ViewState>
  internal var createResource: () -> Void
  internal var createFolder: () -> Void
  internal var close: () -> Void
}

extension ResourcesListCreateMenuController: ViewController {

  internal struct Context: LoadableFeatureContext, Hashable {

    internal var enclosingFolderID: ResourceFolder.ID?
  }

  internal struct ViewState: Hashable {}

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      createResource: unimplemented(),
      createFolder: unimplemented(),
      close: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourcesListCreateMenuController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()

    nonisolated func close() {
      asyncExecutor.schedule(.reuse) { @MainActor in
        await navigation
          .dismissLegacySheet(ResourcesListCreateMenuView.self)
      }
    }

    nonisolated func createResource() {
      asyncExecutor.schedule(.reuse) { @MainActor in
        await navigation
          .dismissLegacySheet(ResourcesListCreateMenuView.self)
        await navigation
          .push(
            legacy: ResourceEditViewController.self,
            context: (
              .new(in: context.enclosingFolderID, url: .none),
              completion: { _ in
                MainActor.execute {
                  await navigation.presentInfoSnackbar(
                    .localized(
                      key: "resource.form.new.password.created"
                    )
                  )
                }
              }
            )
          )
      }
    }

    nonisolated func createFolder() {
      asyncExecutor.schedule(.reuse) { @MainActor in
        await navigation
          .dismissLegacySheet(ResourcesListCreateMenuView.self)
        do {
          try await navigation.push(
            ResourceFolderEditView.self,
            controller: features.instance(
              context: .create(
                containingFolderID: context.enclosingFolderID
              )
            )
          )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    return .init(
      viewState: .init(initial: .init()),
      createResource: createResource,
      createFolder: createFolder,
      close: close
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourcesListCreateMenuController() {
    self.use(
      .disposable(
        ResourcesListCreateMenuController.self,
        load: ResourcesListCreateMenuController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
