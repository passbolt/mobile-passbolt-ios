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
    internal var snackBarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let currentAccount: Account

  private let asyncExecutor: AsyncExecutor
  private let pasteboard: OSPasteboard

  private let accountDetails: AccountDetails
  private let resourceSearchController: ResourceSearchController
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

    self.pasteboard = features.instance()

    self.currentAccount = try features.sessionAccount()

    self.asyncExecutor = try features.instance()

    self.accountDetails = try features.instance(context: currentAccount)
    self.resourceSearchController = try features.instance(
      context: .init(
        text: .init(),
        includedTypes: [.totp, .passwordWithTOTP]
      )
    )
    self.resourceEditPreparation = try features.instance()

    self.navigationToAccountMenu = try features.instance()
    self.navigationToOTPEditMenu = try features.instance()

    self.viewState = .init(
      initial: .init(
        searchText: .init(),
        otpResources: .init(),
        snackBarMessage: .none
      ),
      updateFrom: self.resourceSearchController.state,
      transform: { (viewState: inout ViewState, searchState: ResourceSearchState) in
        var otpResources: OrderedDictionary<Resource.ID, TOTPResourceViewModel> = .init()
        otpResources.reserveCapacity(searchState.result.count)
        for item: ResourceSearchResultItem in searchState.result {
          otpResources[item.id] = .init(
            id: item.id,
            name: item.name,
            generateTOTP: .none
          )
        }
        viewState.otpResources = otpResources
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
    await withLogCatch(
      fallback: { (error: Error) in
        self.viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
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
    await withLogCatch(
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(.totp, .none, .none)
      await self.navigationToOTPEditMenu.performCatching(
        context: .init(
          editingContext: editingContext,
          showMessage: { [viewState] (message: SnackBarMessage?) in
            viewState.update(\.snackBarMessage, to: message)
          }
        )
      )
    }
  }

  private func revealOTP(
    for resourceID: Resource.ID
  ) async throws -> TOTPValue {
    guard let resourceItem = await self.viewState.current.otpResources[resourceID]
    else {
      throw
        MissingResourceData
        .error("Attempting to reveal OTP for not visible item!")
    }

    // no need to update if there is already reveqaled
    if let generator: @Sendable () -> TOTPValue = resourceItem.generateTOTP {
      return generator()
    }
    else {
      let features: Features =
        self.features.branchIfNeeded(
          scope: ResourceDetailsScope.self,
          context: resourceID
        ) ?? features

      let resource: ResourceController = try features.instance()
      try await resource.fetchSecretIfNeeded()

      guard let totpSecret: TOTPSecret = try await resource.firstTOTPSecret()
      else {
        throw
          ResourceSecretInvalid
          .error("Failed to acecss TOTP secret!")
      }

      let generator: @Sendable () -> TOTPValue =
        try features
        .instance(
          of: TOTPCodeGenerator.self,
          context: .init(
            resourceID: resourceID,
            totpSecret: totpSecret
          )
        )
        .generate

      self.viewState.update { (viewState: inout ViewState) in
        for key in viewState.otpResources.keys {
          if key == resourceItem.id {
            viewState.otpResources[key]?.generateTOTP = generator
          }
          else {  // clear revealed otp
            viewState.otpResources[key]?.generateTOTP = .none
          }
        }
      }
      return generator()
    }
  }

  private func copyTOTP(
    _ value: TOTPValue
  ) async throws {
    pasteboard.put(value.otp.rawValue)
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

  internal func revealAndCopyOTP(
    for resourceID: Resource.ID
  ) async {
    await withLogCatch(
      failInfo: "Failed to reveal or copy OTP.",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      try await self.copyTOTP(self.revealOTP(for: resourceID))
    }
  }

  internal func showCentextualMenu(
    for resourceID: Resource.ID
  ) async {
    await withLogCatch(
      failInfo: "Failed to navigate to OTP contextual menu.",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      hideOTPCodes()
      let features: Features =
        features.branchIfNeeded(
          scope: ResourceDetailsScope.self,
          context: resourceID
        ) ?? features
      let navigationToContextualMenu: NavigationToResourceOTPContextualMenu = try features.instance()
      try await navigationToContextualMenu.perform(
        context: .init(
          revealOTP: { [self] in
            await self.revealAndCopyOTP(for: resourceID)
          },
          showMessage: { [viewState] (message: SnackBarMessage?) in
            viewState.update { state in
              state.snackBarMessage = message
            }
          }
        )
      )
    }
  }

  internal func showAccountMenu() async {
    await withLogCatch(
      failInfo: "Failed to navigate to account menu.",
      fallback: { [viewState] (error: Error) in
        viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      hideOTPCodes()
      try await navigationToAccountMenu.perform()
    }
  }

  internal func hideOTPCodes() {
    self.viewState.update { (viewState: inout ViewState) in
      for key in viewState.otpResources.keys {
        viewState.otpResources[key]?.generateTOTP = .none
      }
    }
  }
}

internal struct TOTPResourceViewModel {

  internal var id: Resource.ID
  internal var name: String
  internal var generateTOTP: (@Sendable () -> TOTPValue)?
}

extension TOTPResourceViewModel: Equatable {

  internal static func == (
    _ lhs: TOTPResourceViewModel,
    _ rhs: TOTPResourceViewModel
  ) -> Bool {
    lhs.id == rhs.id
      && lhs.name == rhs.name
      // those are not equal if one has generator and other does not
      // can't verify if both generators are the same though
      && (lhs.generateTOTP == nil && rhs.generateTOTP == nil)
  }
}

extension TOTPResourceViewModel: Identifiable {}
