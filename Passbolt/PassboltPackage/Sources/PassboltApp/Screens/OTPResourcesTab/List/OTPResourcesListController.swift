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
    let pasteboard: OSPasteboard = features.instance()

    let asyncExecutor: AsyncExecutor = try features.instance()

    let otpResources: OTPResources = try features.instance()

    let accountDetails: AccountDetails = try features.instance(context: currentAccount)

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToCreateOTPMenu: NavigationToCreateOTPMenu = try features.instance()

    let revealedTOTPState: CriticalState<RevealedTOTPState?> = .init(.none) { state in
      // make sure updates won't leak
      state?.viewUpdatesExecution.cancel()
    }

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        searchText: .init(),
        otpResources: .init(),
        snackBarMessage: .none
      )
    )

    // load avatar image for search icon
    asyncExecutor.schedule {
      do {
        let avatarImage: Data? = try await accountDetails.avatarImage()
        await viewState
          .update(
            \.accountAvatarImage,
            to: avatarImage
          )
      }
      catch {
        diagnostics
          .log(
            error: error,
            info: .message(
              "Failed to get account avatar image!"
            )
          )
      }
    }

    // start list content updates
    asyncExecutor.schedule {
      let searchTextSequence: AnyAsyncSequence<String> = ObservableViewState(
        from: viewState,
        at: \.searchText
      )
      .asAnyAsyncSequence()

      do {
        let contentQueryUpdates:
          AsyncMapSequence<AsyncCombineLatest2Sequence<UpdatesSequence, AnyAsyncSequence<String>>, OTPResourcesFilter> =
            combineLatest(
              otpResources.updates,
              searchTextSequence
            )
            .map { _, searchText in
              OTPResourcesFilter(text: searchText)
            }

        for await query in contentQueryUpdates {
          let filteredResourcesList: Array<OTPResourceListItemDSV> = try await otpResources.filteredList(query)

          hideOTPCodes()

          await viewState.update { (state: inout ViewState) in
            state.otpResources =
              filteredResourcesList
              .map { (resource: OTPResourceListItemDSV) -> TOTPResourceViewModel in
                .init(
                  id: resource.id,
                  name: resource.name,
                  // we are hiding OTP when list changes
                  totpValue: .none
                )
              }
          }
        }
      }
      catch {
        diagnostics
          .log(
            error: error,
            info: .message(
              "OTP list updates broken!"
            )
          )
      }
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
      asyncExecutor.schedule(.reuse) {
        await diagnostics
          .withLogCatch(
            info: .message("Navigation to create OTP failed!")
          ) {
            try await navigationToCreateOTPMenu.perform()
          }
      }
    }

    nonisolated func revealAndCopyOTP(
      for id: Resource.ID
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          if  // if it was already revealed just copy the code
          let revealedTOTPState: RevealedTOTPState = revealedTOTPState.get(\.self),
            revealedTOTPState.resourceID == id,
            let otp: OTP = await revealedTOTPState.totpCodes.first()?.otp
          {
            pasteboard.put(otp.rawValue)

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
          else {
            // prepare codes sequence
            let totpCodes: AnyAsyncSequence<TOTPValue> = try await otpResources.totpCodesFor(id)

            // get the first code
            guard let totpValue: TOTPValue = await totpCodes.first(), !Task.isCancelled
            else { return }  // ignore, cancelled

            // prepare automatic view updates
            let viewUpdatesExecution = scheduleTOTPViewUpdates(
              for: id,
              totpCodes: totpCodes
            )

            // save revealed item state
            revealedTOTPState.access { (state: inout RevealedTOTPState?) in
              // cancel previous view updates if any
              state?.viewUpdatesExecution.cancel()
              state = .init(
                resourceID: id,
                totpCodes: totpCodes,
                viewUpdatesExecution: viewUpdatesExecution
              )
            }

            // put code into pasteboard
            pasteboard.put(totpValue.otp.rawValue)

            // update view state with initial code
            await viewState.update { (state: inout ViewState) in
              guard let index = state.otpResources.firstIndex(where: { $0.id == id })
              // can't update, might be an error?
              else { return }
              state.otpResources[index].totpValue = totpValue

              state.snackBarMessage = .info(
                .localized(
                  key: "otp.value.copied.message"
                )
              )
            }
          }
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

    @Sendable nonisolated func scheduleTOTPViewUpdates(
      for id: Resource.ID,
      totpCodes: AnyAsyncSequence<TOTPValue>
    ) -> AsyncExecutor.Execution {
      // there can be at most one OTP code
      // revealed at the same time
      asyncExecutor.schedule(.replace) {
        do {
          for try await totpValue: TOTPValue in totpCodes {
            try await viewState.update { (state: inout ViewState) in
              guard let index = state.otpResources.firstIndex(where: { $0.id == id })
              else { throw Cancelled.error() }
              state.otpResources[index].totpValue = totpValue
            }
          }
        }
        catch is Cancelled {
          // NOP - ignore cancelled
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "TOTP sequence broken!"
              )
            )
        }

        // hide OTP code when updates ends
        await viewState.update { (state: inout ViewState) in
          guard let index = state.otpResources.firstIndex(where: { $0.id == id })
          else { return }
          state.otpResources[index].totpValue = .none
        }
      }
    }

    nonisolated func showCentextualMenu(
      for id: Resource.ID
    ) {
      asyncExecutor.schedule(.reuse) {
        #warning("TODO: [MOB-1082]")
      }
    }

    nonisolated func showAccountMenu() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToAccountMenu.perform()
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Navigation to account menu failed!"
              )
            )
        }
      }
    }

    @Sendable nonisolated func hideOTPCodes() {
      revealedTOTPState.access { (state: inout RevealedTOTPState?) in
        // it will hide OTP code automatically
        state?.viewUpdatesExecution.cancel()
        state = .none
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
  fileprivate var totpCodes: AnyAsyncSequence<TOTPValue>
  fileprivate var viewUpdatesExecution: AsyncExecutor.Execution
}
