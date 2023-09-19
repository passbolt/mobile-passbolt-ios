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
import FeatureScopes
import Foundation
import OSFeatures
import Resources
import Session
import SessionData

internal final class OTPResourcesListViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var accountAvatarImage: Data?
    internal var searchText: String
    internal var otpResources: OrderedDictionary<Resource.ID, TOTPResourceViewModel>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal let createAvailable: Bool

  private let currentAccount: Account

  private let asyncExecutor: AsyncExecutor
  private let pasteboard: OSPasteboard

  private let accountDetails: AccountDetails
  private let resourceSearchController: ResourceSearchController
  private let resourcesOTPController: ResourcesOTPController
  private let resourceEditPreparation: ResourceEditPreparation

  private let navigationToAccountMenu: NavigationToAccountMenu
  private let navigationToOTPEditMenu: NavigationToResourceOTPEditMenu

  private let features: Features

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features

    self.createAvailable = try features.sessionConfiguration().totpEnabled

    self.pasteboard = features.instance()

    self.currentAccount = try features.sessionAccount()

    self.asyncExecutor = try features.instance()

    self.accountDetails = try features.instance()
    self.resourceSearchController = try features.instance()
		self.resourceSearchController.updateFilter { filter in
			// set initial filter
			filter.includedTypes = [.totp, .passwordWithTOTP]
		}
    self.resourcesOTPController = try features.instance()
    self.resourceEditPreparation = try features.instance()

    self.navigationToAccountMenu = try features.instance()
    self.navigationToOTPEditMenu = try features.instance()

    self.viewState = .init(
      initial: .init(
        searchText: .init(),
        otpResources: .init()
      ),
      updateFrom: self.resourceSearchController.state,
      update: { [resourcesOTPController] (updateState, update: Update<ResourceSearchState>) in
        do {
          let searchState: ResourceSearchState = try update.value
          var otpResources: OrderedDictionary<Resource.ID, TOTPResourceViewModel> = .init()
          otpResources.reserveCapacity(searchState.result.count)
          for item: ResourceSearchResultItem in searchState.result {
            let otpIterator: AnyAsyncIterator<OTPValue?> = resourcesOTPController
              .currentOTP
              .asAnyAsyncSequence()
              .map { (update: Update<OTPValue>) -> OTPValue? in
                if let otp: OTPValue = try? update.value, otp.resourceID == item.id {
                  return otp
                }
                else {
                  return .none
                }
              }
              .removeDuplicates()
              .makeAsyncIterator()
              .asAnyAsyncIterator()

            otpResources[item.id] = .init(
              id: item.id,
              name: item.name,
              generateOTP: { () async -> OTPValue? in
                (try? await otpIterator.next())?.flatMap { $0 }
              }
            )
          }
          await updateState { (viewState: inout ViewState) in
            viewState.otpResources = otpResources
          }
        }
        catch {
					SnackBarMessageEvent.send(.error(error))
        }
      }
    )

    // load avatar image for search icon
    self.asyncExecutor.scheduleCatching(
      failMessage: "Failed to get account avatar image!"
    ) { [viewState, accountDetails] in
      let avatarImage: Data? = try await accountDetails.avatarImage()
      await viewState
        .update(
          \.accountAvatarImage,
          to: avatarImage
        )
    }
  }
}

extension OTPResourcesListViewController {

  @Sendable internal func refreshList() async {
    await consumingErrors {
      try await self.resourceSearchController.refreshIfNeeded()
    }
  }

  internal func setSearch(text: String) {
    self.resourceSearchController.updateFilter { filter in
      filter.text = text
      filter.includedTypes = [.totp, .passwordWithTOTP]
    }
  }

  internal func createOTP() async {
    await consumingErrors {
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(.totp, .none, .none)
      await self.navigationToOTPEditMenu.performCatching(
        context: .init(
          editingContext: editingContext
        )
      )
    }
  }

	@discardableResult
  private func revealOTP(
    for resourceID: Resource.ID
  ) async throws -> OTPValue {
    try await self.resourcesOTPController.revealOTP(resourceID)
  }

  private func copyOTP(
    _ value: OTPValue
  ) async throws {
    pasteboard.put(value.otp.rawValue)
    SnackBarMessageEvent.send("otp.value.copied.message")
  }

  internal func revealAndCopyOTP(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to reveal or copy OTP."
		) {
      try await self.copyOTP(self.revealOTP(for: resourceID))
    }
  }

  internal func showCentextualMenu(
    for resourceID: Resource.ID
  ) async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to OTP contextual menu."
		) {
      self.hideOTPCodes()
      let features: Features =
        try features.branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )
      let navigationToContextualMenu: NavigationToResourceOTPContextualMenu = try features.instance()
      try await navigationToContextualMenu.perform(
        context: .init(
          revealOTP: { [self] in
						await consumingErrors(
							errorDiagnostics: "Failed to reveal OTP."
						) {
							try await self.revealOTP(for: resourceID)
						}
          }
        )
      )
    }
  }

  internal func showAccountMenu() async {
    await consumingErrors(
      errorDiagnostics: "Failed to navigate to account menu."
		) {
      self.hideOTPCodes()
      try await navigationToAccountMenu.perform()
    }
  }

  internal func hideOTPCodes() {
    self.resourcesOTPController.hideOTP()
  }
}

internal struct TOTPResourceViewModel {

  internal var id: Resource.ID
  internal var name: String
  internal var generateOTP: @Sendable () async -> OTPValue?
}

extension TOTPResourceViewModel: Equatable {

  internal static func == (
    _ lhs: TOTPResourceViewModel,
    _ rhs: TOTPResourceViewModel
  ) -> Bool {
    lhs.id == rhs.id
      && lhs.name == rhs.name
  }
}

extension TOTPResourceViewModel: Identifiable {}
