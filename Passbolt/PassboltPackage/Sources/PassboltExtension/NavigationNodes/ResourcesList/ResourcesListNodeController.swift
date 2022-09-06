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
import Session
import SessionData
import SharedUIComponents
import Users

internal struct ResourcesListNodeController {

  internal var viewState: DisplayViewState<ViewState>
  internal var searchController: ResourceSearchDisplayController
  internal var contentController: ResourcesListDisplayController
  internal var closeExtension: () -> Void
}

extension ResourcesListNodeController: NavigationNodeController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

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
      viewState: .placeholder,
      searchController: .placeholder,
      contentController: .placeholder,
      closeExtension: unimplemented()
    )
  }
  #endif
}

extension ResourcesListNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let autofillContext: AutofillExtensionContext = features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        title: context.title,
        titleIconName: context.titleIconName,
        snackBarMessage: .none
      )
    )

    let viewState: DisplayViewState<ViewState> = .init(stateSource: state)

    let searchController: ResourceSearchDisplayController = try await features.instance(
      context: .init(
        searchPrompt: context.searchPrompt,
        showMessage: { (message: SnackBarMessage?) in
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    let contentController: ResourcesListDisplayController = try await features.instance(
      context: .init(
        filter:
          searchController
          .searchText
          .convert { (text: String) -> ResourcesFilter in
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
          state.set(\.snackBarMessage, to: message)
        }
      )
    )

    @Sendable nonisolated func createResource() {
      asyncExecutor.schedule(.reuse) {
        await navigationTree
          .push(
            ResourceEditViewController.self,
            context: (
              editing: .new(in: .none, url: requestedServiceIdentifiers.first.map { URLString(rawValue: $0.rawValue) }),
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
          let resource: ResourceDetailsDSV = try await resourceDetails.details()
          let secret: ResourceSecret = try await resourceDetails.secret()

          guard let password: String = secret.password
          else {
            throw
              ResourceSecretInvalid
              .error("Missing resource password in secret.")
          }
          await autofillContext
            .completeWithCredential(
              AutofillExtensionContext.Credential(
                user: resource.username ?? "",
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
          state.set(\.snackBarMessage, to: .error(error))
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
      searchController: searchController,
      contentController: contentController,
      closeExtension: closeExtension
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourcesListNodeController() {
    self.use(
      .disposable(
        ResourcesListNodeController.self,
        load: ResourcesListNodeController.load(features:context:)
      )
    )
  }
}
