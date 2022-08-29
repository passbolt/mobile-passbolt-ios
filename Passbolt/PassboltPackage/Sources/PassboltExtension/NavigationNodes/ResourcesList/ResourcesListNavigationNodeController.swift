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

internal struct ResourcesListNavigationNodeController {

  internal var displayViewState: DisplayViewState<ViewState>
  internal var activate: () async -> Void
  internal var refresh: () async -> Void
  internal var updateSearchText: (String) -> Void
  internal var createResource: () -> Void
  internal var selectResource: (Resource.ID) -> Void
  internal var showPresentationMenu: () -> Void
  internal var signOut: () -> Void
  internal var closeExtension: () -> Void
}

extension ResourcesListNavigationNodeController: ContextlessNavigationNodeController {

  internal struct ViewState: Hashable {

    internal var title: DisplayableString
    internal var accountAvatar: Data?
    internal var searchText: String
    internal var suggested: Array<ResourceListItemDSV>
    internal var resources: Array<ResourceListItemDSV>
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      displayViewState: .placeholder,
      activate: { unimplemented() },
      refresh: { unimplemented() },
      updateSearchText: { _ in unimplemented() },
      createResource: { unimplemented() },
      selectResource: { _ in unimplemented() },
      showPresentationMenu: { unimplemented() },
      signOut: { unimplemented() },
      closeExtension: { unimplemented() }
    )
  }
  #endif
}

extension ResourcesListNavigationNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let autofillContext: AutofillExtensionContext = features.instance()
    let session: Session = try await features.instance()
    let sessionData: SessionData = try await features.instance()
    let accountDetails: AccountDetails = try await features.instance(context: session.currentAccount())
    let resources: Resources = try await features.instance()

    let requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> =
      autofillContext.requestedServiceIdentifiers()

    let displayViewState: DisplayViewState<ViewState> = .init(
      initial: .init(
        title: .localized("autofill.extension.resource.list.title"),
        accountAvatar: .none,
        searchText: "",
        suggested: .init(),
        resources: .init(),
        snackBarMessage: .none
      )
    )

    nonisolated func activate() async {
      Task {
        do {
          let avatar: Data? = try await accountDetails.avatarImage()
          displayViewState.with { state in
            state.accountAvatar = avatar
          }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to load account avatar image, using placeholder."
            )
          )
        }
      }

      do {
        try await sessionData.updatesSequence.forLatest {
          do {
            let filteredResources =
              try await resources.filteredResourcesList(
                .init(sorting: .nameAlphabetically, text: displayViewState.searchText)
              )
            displayViewState.suggested = filteredResources.filter { resource in
              requestedServiceIdentifiers.matches(resource)
            }
            displayViewState.resources = filteredResources
          }
          catch {
            diagnostics.log(
              error: error,
              info: .message(
                "Failed to load resources from the database."
              )
            )
            displayViewState.snackBarMessage = .error(error)
          }
        }
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Resources list updates broken!"
          )
        )
        displayViewState.snackBarMessage = .error(error)
      }
    }

    nonisolated func refresh() async {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Failed to refresh session data."
          )
        )
        displayViewState.snackBarMessage = .error(error)
      }
    }

    nonisolated func updateSearchText(
      _ text: String
    ) {
      displayViewState.searchText = text
      Task {
        do {
          let filteredResources =
            try await resources.filteredResourcesList(
              .init(sorting: .nameAlphabetically, text: displayViewState.searchText)
            )
          displayViewState.suggested = filteredResources.filter { resource in
            requestedServiceIdentifiers.matches(resource)
          }
          displayViewState.resources = filteredResources
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to load resources from the database."
            )
          )
          displayViewState.snackBarMessage = .error(error)
        }
      }
    }

    nonisolated func createResource() {
      Task {
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
      Task {
        do {
          let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
          let resource: ResourceDetailsDSV = try await resourceDetails.details()
          let secret: ResourceSecret = try await resourceDetails.secret()

          guard let password: String = secret.password
          else {
            throw
              ResourceSecretInvalid
              .error("Missing resource password ine secret.")
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
              "Failed to use resource for autofill."
            )
          )
          displayViewState.snackBarMessage = .error(error)
        }
      }
    }

    nonisolated func showPresentationMenu() {
      let error: Unimplemented = .error("Not implemented yet")
      displayViewState.snackBarMessage = .error(error)
    }

    nonisolated func signOut() {
      Task {
        await session.close(.none)
      }
    }

    nonisolated func closeExtension() {
      Task {
        await autofillContext.cancelAndCloseExtension()
      }
    }

    return .init(
      displayViewState: displayViewState,
      activate: activate,
      refresh: refresh,
      updateSearchText: updateSearchText(_:),
      createResource: createResource,
      selectResource: selectResource(_:),
      showPresentationMenu: showPresentationMenu,
      signOut: signOut,
      closeExtension: closeExtension
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltPlainResourcesListNavigationNodeController() {
    self.use(
      .disposable(
        ResourcesListNavigationNodeController.self,
        load: ResourcesListNavigationNodeController.load(features:)
      )
    )
  }
}
