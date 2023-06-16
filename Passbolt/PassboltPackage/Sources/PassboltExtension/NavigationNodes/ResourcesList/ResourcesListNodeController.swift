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
import Session
import SessionData
import SharedUIComponents
import Users

internal final class ResourcesListNodeController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourcesListDisplayController!  // lazy init?

  private let diagnostics: OSDiagnostics
  private let navigationTree: NavigationTree
  private let asyncExecutor: AsyncExecutor
  private let autofillContext: AutofillExtensionContext

  private let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier>

  private let context: Context
  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.diagnostics = features.instance()
    self.navigationTree = features.instance()
    self.asyncExecutor = try features.instance()
    self.autofillContext = features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()
    self.requestedServiceIdentifiers = requestedServiceIdentifiers

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )
    self.viewState = viewState

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )

    self.contentController = try features.instance(
      context: .init(
        filter: self.searchController
          .searchText
					.asAnyAsyncSequence()
          .map { (text: String) -> ResourcesFilter in
            var filter: ResourcesFilter = context.baseFilter
            filter.text = text
            return filter
          }
					.asAnyAsyncSequence(),
        suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
          requestedServiceIdentifiers.matches(resource)
        },
        createResource: self.createResource,
        selectResource: self.selectResource(_:),
        openResourceMenu: .none,
        showMessage: { (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )
  }
}

extension ResourcesListNodeController {

  internal struct Context {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var searchPrompt: DisplayableString = .localized(key: "resources.search.placeholder")
    internal var baseFilter: ResourcesFilter
  }

  internal struct ViewState: Hashable {

    internal var title: DisplayableString
    internal var titleIconName: ImageNameConstant
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension ResourcesListNodeController {

  internal final func createResource() {
    self.asyncExecutor.schedule(.reuse) { [weak self, features, navigationTree, requestedServiceIdentifiers] in
      await navigationTree
        .push(
          ResourceEditViewController.self,
          context: (
            editing: .create(
              folderID: .none,
              uri: requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
            ),
            completion: { [weak self] resourceID in
              self?.selectResource(resourceID)
            }
          ),
          using: features
        )
    }
  }

  internal final func selectResource(
    _ resourceID: Resource.ID
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to handle resource selection.",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .replace
    ) { [features, autofillContext] in
      let resourceController: ResourceController = try await features.instance()
      try await resourceController.fetchSecretIfNeeded(force: true)
      let resource: Resource = try await resourceController.state.value

      guard let password: String = resource.secret.password.stringValue ?? resource.secret.secret.stringValue
      else {
        throw
          ResourceSecretInvalid
          .error("Missing resource password in secret.")
      }
      await autofillContext
        .completeWithCredential(
          AutofillExtensionContext.Credential(
            user: resource.meta.username.stringValue ?? "",
            password: password
          )
        )
    }
  }

  internal final func closeExtension() {
    self.asyncExecutor.schedule(.reuse) { [autofillContext] in
      await autofillContext.cancelAndCloseExtension()
    }
  }
}
