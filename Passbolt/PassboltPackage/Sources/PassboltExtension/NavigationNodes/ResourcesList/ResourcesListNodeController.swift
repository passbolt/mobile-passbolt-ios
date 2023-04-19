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

internal struct ResourcesListNodeController {

  internal var viewState: MutableViewState<ViewState>
  internal var closeExtension: () -> Void
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourcesListDisplayController
}

extension ResourcesListNodeController: ViewController {

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

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      closeExtension: { unimplemented() },
      searchController: .placeholder,
      contentController: .placeholder
    )
  }
  #endif
}

extension ResourcesListNodeController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let autofillContext: AutofillExtensionContext = features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )

    let searchController: ResourceSearchDisplayController = try features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )

    let contentController: ResourcesListDisplayController = try features.instance(
      context: .init(
        filter: searchController
          .searchText
          .map { (text: String) -> ResourcesFilter in
            var filter: ResourcesFilter = context.baseFilter
            filter.text = text
            return filter
          },
        suggestionFilter: { (resource: ResourceListItemDSV) -> Bool in
          requestedServiceIdentifiers.matches(resource)
        },
        createResource: createResource,
        selectResource: selectResource(_:),
        openResourceMenu: .none,
        showMessage: { (message: SnackBarMessage?) in
          viewState.update { viewState in
            viewState.snackBarMessage = message
          }
        }
      )
    )

    @Sendable nonisolated func createResource() {
      asyncExecutor.schedule(.reuse) {
        await navigationTree
          .push(
            ResourceEditViewController.self,
            context: (
              editing: .create(
                folderID: .none,
                uri: requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }
              ),
              completion: { resourceID in
                selectResource(resourceID)
              }
            ),
            using: features
          )
      }
    }

    @Sendable nonisolated func selectResource(
      _ resourceID: Resource.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
          let resource: Resource = try await resourceDetails.details()
          let secret: ResourceSecret = try await resourceDetails.secret()

          guard
            let passwordField: ResourceField = resource.type.password,
            let password: String = secret.value(for: passwordField)?.stringValue
          else {
            throw
              ResourceSecretInvalid
              .error("Missing resource password in secret.")
          }
          await autofillContext
            .completeWithCredential(
              AutofillExtensionContext.Credential(
                user: resource.value(for: .unknownNamed("username"))?.stringValue ?? "",
                password: password
              )
            )
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to handle resource selection."
            )
          )
          await viewState.update { viewState in
            viewState.snackBarMessage = .error(error)
          }
        }
      }
    }

    nonisolated func closeExtension() {
      asyncExecutor.schedule(.reuse) {
        await autofillContext.cancelAndCloseExtension()
      }
    }

    return .init(
      viewState: viewState,
      closeExtension: closeExtension,
      searchController: searchController,
      contentController: contentController
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourcesListNodeController() {
    self.use(
      .disposable(
        ResourcesListNodeController.self,
        load: ResourcesListNodeController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
