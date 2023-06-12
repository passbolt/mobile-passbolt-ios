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

import Accounts
import Display
import Foundation
import OSFeatures
import Resources
import Session
import SessionData

internal final class OTPResourcesListController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let currentAccount: Account
  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let otpResources: OTPResources
  private let otpCodesController: OTPCodesController
  private let accountDetails: AccountDetails
  private let navigationToAccountMenu: NavigationToAccountMenu
  private let navigationToOTPCreateMenu: NavigationToOTPCreateMenu

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features

    self.currentAccount = try features.sessionAccount()
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.otpResources = try features.instance()
    self.otpCodesController = try features.instance()
    self.accountDetails = try features.instance(context: currentAccount)
    self.navigationToAccountMenu = try features.instance()
    self.navigationToOTPCreateMenu = try features.instance()

    self.viewState = .init(
      initial: .init(
        searchText: .init(),
        otpResources: .init(),
        snackBarMessage: .none
      )
    )

    // load avatar image for search icon
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to get account avatar image!"
    ) { [viewState, accountDetails] in
      let avatarImage: Data? = try await accountDetails.avatarImage()
      await viewState
        .update(
          \.accountAvatarImage,
          to: avatarImage
        )
    }

    let lastRevealed: CriticalState<Resource.ID?> = .init(.none)
    self.asyncExecutor
      .scheduleIteration(
        over: self.otpCodesController.updates
          .map(self.otpCodesController.current),
        catchingWith: self.diagnostics,
        failMessage: "OTP codes updates broken!",
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        }
      ) { [viewState] (otpValue: OTPValue?) async throws -> Void in
        defer { lastRevealed.set(\.self, otpValue?.resourceID) }
        if let otpValue {
          let lastRevealed: Resource.ID? = lastRevealed.get(\.self)
          await viewState.update { (state: inout ViewState) in
            if let lastRevealed, otpValue.resourceID != lastRevealed,
              let index = state.otpResources.firstIndex(where: { $0.id == lastRevealed })
            {
              state.otpResources[index].totpValue = .none
            }  // else NOP

            guard let index = state.otpResources.firstIndex(where: { $0.id == otpValue.resourceID })
            else { return }

            switch otpValue {
            case .totp(let value):
              state.otpResources[index].totpValue = value

            case .hotp:
              break  // not supported yet
            }
          }
        }
        else {  // make sure that no leftovers are visible
          await viewState.update { (state: inout ViewState) in
            for index in state.otpResources.indices {
              state.otpResources[index].totpValue = .none
            }
          }
        }
      }

    // start list content updates
    let filtersSequence: AnyAsyncSequence<OTPResourcesFilter> =
      combineLatest(
        ObservableViewState(
          from: viewState,
          at: \.searchText
        ),
        otpResources.updates
      )
      .map { (searchText: String, _) -> OTPResourcesFilter in
        OTPResourcesFilter(text: searchText)
      }
      .asAnyAsyncSequence()

    self.asyncExecutor.scheduleIteration(
      over: filtersSequence,
      catchingWith: self.diagnostics,
      failMessage: "OTP list updates broken!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) { [viewState, otpResources, otpCodesController] (filter: OTPResourcesFilter) in
      let filteredResourcesList: Array<TOTPResourceViewModel> =
        try await otpResources
        .filteredList(filter)
        .map { (resource: ResourceListItemDSV) -> TOTPResourceViewModel in
          .init(
            id: resource.id,
            name: resource.name,
            // we are hiding all OTPs when list changes
            totpValue: .none
          )
        }

      await viewState
        .update(
          \.otpResources,
          to: filteredResourcesList
        )
      await otpCodesController.dispose()
    }
  }
}

extension OTPResourcesListController {

  internal struct ViewState: Equatable {

    internal var accountAvatarImage: Data?
    internal var searchText: String
    internal var otpResources: Array<TOTPResourceViewModel>
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension OTPResourcesListController {

  internal final func refreshList() async {
    do {
      try await self.otpResources.refreshIfNeeded()
    }
    catch {
      self.diagnostics
        .log(
          error: error,
          info: .message(
            "Failed to refresh otp resources data."
          )
        )

      self.viewState
        .update(
          \.snackBarMessage,
          to: .error(error)
        )
    }
  }

  internal final func createOTP() {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Navigation to OTP create menu failed!",
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        },
        behavior: .reuse
      ) { [otpCodesController, navigationToOTPCreateMenu] in
        await otpCodesController.dispose()
        try await navigationToOTPCreateMenu.perform()
      }
  }

  private final func revealOTP(
    for resourceID: Resource.ID
  ) async throws {
    _ = try await self.otpCodesController.requestNextFor(resourceID)
  }

  private final func copyOTP(
    for resourceID: Resource.ID
  ) async throws {
    try await self.otpCodesController.copyFor(resourceID)
    self.viewState
      .update(
        \.snackBarMessage,
        to: .info(
          .localized(
            key: "otp.value.copied.message"
          )
        )
      )
  }

  internal final func revealAndCopyOTP(
    for resourceID: Resource.ID
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Failed to reveal/copy OTP value!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [self] in
      try await self.revealOTP(for: resourceID)
      try await self.copyOTP(for: resourceID)
    }
  }

  internal final func showCentextualMenu(
    for resourceID: Resource.ID
  ) {
    self.asyncExecutor
      .scheduleCatchingWith(
        self.diagnostics,
        failMessage: "Failed to present OTP contextual menu",
        failAction: { [viewState] (error: Error) in
          await viewState.update(\.snackBarMessage, to: .error(error))
        },
        behavior: .reuse
      ) { @MainActor [self, viewState, otpCodesController, features] in
        await otpCodesController.dispose()
        let features: Features =
          features.branchIfNeeded(
            scope: ResourceDetailsScope.self,
            context: resourceID
          ) ?? features
        let navigationToContextualMenu: NavigationToResourceContextualMenu = try features.instance()
        try await navigationToContextualMenu.perform(
          context: .init(
            revealOTP: { [self] in
              self.revealAndCopyOTP(for: resourceID)
            },
            showMessage: { (message: SnackBarMessage?) in
              viewState.update { state in
                state.snackBarMessage = message
              }
            }
          )
        )
      }
  }

  internal final func showAccountMenu() {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      failMessage: "Navigation to account menu failed!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      },
      behavior: .reuse
    ) { [otpCodesController, navigationToAccountMenu] in
      await otpCodesController.dispose()
      try await navigationToAccountMenu.perform()
    }
  }

  internal final func hideOTPCodes() {
    self.asyncExecutor.schedule(.reuse) { [otpCodesController] in
      await otpCodesController.dispose()
    }
  }
}

internal struct TOTPResourceViewModel {

  internal var id: Resource.ID
  internal var name: String
  internal var totpValue: TOTPValue?
}

extension TOTPResourceViewModel: Equatable {}
extension TOTPResourceViewModel: Identifiable {}

private struct RevealedTOTPState {

  fileprivate var resourceID: Resource.ID
  fileprivate var totpCodes: TOTPCodes
  fileprivate var viewUpdatesExecution: AsyncExecutor.Execution
}
