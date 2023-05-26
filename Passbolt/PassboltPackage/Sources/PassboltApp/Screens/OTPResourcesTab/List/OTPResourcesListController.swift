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

// MARK: - Interface

internal struct OTPResourcesListController {

  internal var viewState: MutableViewState<ViewState>

  internal var refreshList: @Sendable () async -> Void
  internal var createOTP: () -> Void
  internal var revealAndCopyOTP: (Resource.ID) -> Void
  internal var showCentextualMenu: (Resource.ID) -> Void
  internal var showAccountMenu: () -> Void
  internal var hideOTPCodes: () -> Void
}

extension OTPResourcesListController: ViewController {

  internal struct ViewState: Equatable {

    internal var accountAvatarImage: Data?
    internal var searchText: String
    internal var otpResources: Array<TOTPResourceViewModel>
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      refreshList: unimplemented0(),
      createOTP: unimplemented0(),
      revealAndCopyOTP: unimplemented1(),
      showCentextualMenu: unimplemented1(),
      showAccountMenu: unimplemented0(),
      hideOTPCodes: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPResourcesListController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()

    let asyncExecutor: AsyncExecutor = try features.instance()

    let otpResources: OTPResources = try features.instance()
    let otpCodesController: OTPCodesController = try features.instance()

    let accountDetails: AccountDetails = try features.instance(context: currentAccount)

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToOTPCreateMenu: NavigationToOTPCreateMenu = try features.instance()
    let navigationToOTPContextualMenu: NavigationToOTPContextualMenu = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        searchText: .init(),
        otpResources: .init(),
        snackBarMessage: .none
      )
    )

    // load avatar image for search icon
    asyncExecutor.scheduleCatchingWith(
      diagnostics,
      failMessage: "Failed to get account avatar image!"
    ) {
      let avatarImage: Data? = try await accountDetails.avatarImage()
      await viewState
        .update(
          \.accountAvatarImage,
          to: avatarImage
        )
    }

    // auto present revealed OTP codes
    asyncExecutor.scheduleCatchingWith(
      diagnostics,
      failMessage: "OTP codes updates broken!"
    ) {
      let otpUpdates = otpCodesController.updates.map(otpCodesController.current)
      var lastRevealed: Resource.ID?
      for await otpValue in otpUpdates {
        defer { lastRevealed = otpValue?.resourceID }
        if let otpValue {
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

    asyncExecutor.scheduleIteration(
      over: filtersSequence,
      catchingWith: diagnostics,
      failMessage: "OTP list updates broken!"
    ) { (filter: OTPResourcesFilter) in
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

    @Sendable nonisolated func refreshList() async {
      do {
        try await otpResources.refreshIfNeeded()
      }
      catch {
        diagnostics
          .log(
            error: error,
            info: .message(
              "Failed to refresh otp resources data."
            )
          )

        await viewState
          .update(
            \.snackBarMessage,
            to: .error(error)
          )
      }
    }

    nonisolated func createOTP() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to OTP create menu failed!",
        behavior: .reuse
      ) {
        await otpCodesController.dispose()
        try await navigationToOTPCreateMenu.perform()
      }
    }

    @Sendable nonisolated func revealOTP(
      for resourceID: Resource.ID
    ) async throws {
      try await otpCodesController.requestNextFor(resourceID)
    }

    @Sendable nonisolated func copyOTP(
      for resourceID: Resource.ID
    ) async throws {
      try await otpCodesController.copyFor(resourceID)
      await viewState
        .update(
          \.snackBarMessage,
          to: .info(
            .localized(
              key: "otp.value.copied.message"
            )
          )
        )
    }

    nonisolated func revealAndCopyOTP(
      for resourceID: Resource.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          try await revealOTP(for: resourceID)
          try await copyOTP(for: resourceID)
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Failed to reveal/copy OTP value!"
              )
            )

          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
        }
      }
    }

    nonisolated func showCentextualMenu(
      for resourceID: Resource.ID
    ) {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Failed to present OTP contextual menu",
        behavior: .reuse
      ) {
        await otpCodesController.dispose()
        try await navigationToOTPContextualMenu.perform(
          context: .init(
            resourceID: resourceID,
            showMessage: { (message: SnackBarMessage) in
              viewState.update { state in
                state.snackBarMessage = message
              }
            }
          )
        )
      }
    }

    nonisolated func showAccountMenu() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Navigation to account menu failed!",
        behavior: .reuse
      ) {
        await otpCodesController.dispose()
        try await navigationToAccountMenu.perform()
      }
    }

    @Sendable nonisolated func hideOTPCodes() {
      asyncExecutor.schedule(.reuse) {
        await otpCodesController.dispose()
      }
    }

    return .init(
      viewState: viewState,
      refreshList: refreshList,
      createOTP: createOTP,
      revealAndCopyOTP: revealAndCopyOTP(for:),
      showCentextualMenu: showCentextualMenu(for:),
      showAccountMenu: showAccountMenu,
      hideOTPCodes: hideOTPCodes
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPResourcesListController() {
    self.use(
      .disposable(
        OTPResourcesListController.self,
        load: OTPResourcesListController.load(features:)
      ),
      in: SessionScope.self
    )
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
