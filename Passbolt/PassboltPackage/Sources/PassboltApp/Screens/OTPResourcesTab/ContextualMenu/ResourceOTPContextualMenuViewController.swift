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
import FeatureScopes
import OSFeatures
import Resources
import SharedUIComponents

internal enum ResourceOTPContextualMenuItem: Hashable, Identifiable {

  case revealOTP
  case copyOTP

  case editOTP
  case deleteOTP

  internal var id: Self { self }
}

internal final class ResourceOTPContextualMenuViewController: ViewController {

  internal struct Context {

    internal var revealOTP: (@MainActor () async -> Void)?
  }

  internal struct ViewState: Equatable {

    internal var title: String
    internal var accessMenuItems: Array<ResourceOTPContextualMenuItem>
    internal var modifyMenuItems: Array<ResourceOTPContextualMenuItem>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let resourceController: ResourceController

  private let navigationToSelf: NavigationToResourceOTPContextualMenu
  private let navigationToResourceOTPDeleteAlert: NavigationToResourceOTPDeleteAlert
  private let navigationToTOTPEditMenu: NavigationToResourceOTPEditMenu

  private let linkOpener: OSLinkOpener
  private let pasteboard: OSPasteboard

  private let revealOTP: (@MainActor () async -> Void)?
  private let resourceID: Resource.ID

  private let sessionConfiguration: SessionConfiguration

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(ResourceScope.self)
    self.resourceID = try features.context(of: ResourceScope.self)

    self.features = features.takeOwned()

    self.sessionConfiguration = try features.sessionConfiguration()

    self.revealOTP = context.revealOTP

    self.linkOpener = features.instance()
    self.pasteboard = features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToResourceOTPDeleteAlert = try features.instance()
    self.navigationToTOTPEditMenu = try features.instance()

    self.resourceController = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: "",
        accessMenuItems: .init(),
        modifyMenuItems: .init()
      ),
      updateFrom: self.resourceController.state,
      update: { [revealOTP, sessionConfiguration, navigationToSelf] (updateState, update: Update<Resource>) in
        do {
          let resource: Resource = try update.value
          var accessMenuItems: Array<ResourceOTPContextualMenuItem> = .init()
          if case .some = revealOTP {
            accessMenuItems.append(.revealOTP)
          }  // else NOP

          if resource.hasTOTP {
            accessMenuItems.append(.copyOTP)
          }  // else NOP

          var modifyMenuItems: Array<ResourceOTPContextualMenuItem> = .init()

          if sessionConfiguration.resources.totpEnabled && resource.canEdit {
            if resource.hasTOTP {
              modifyMenuItems.append(.editOTP)
            }  // else NOP

            modifyMenuItems.append(.deleteOTP)
          }  // else NOP

          await updateState { (viewState: inout ViewState) in
            viewState.title = resource.name
            viewState.accessMenuItems = accessMenuItems
            viewState.modifyMenuItems = modifyMenuItems
          }
        }
        catch {
          await navigationToSelf.revertCatching()
        }
      }
    )
  }
}

extension ResourceOTPContextualMenuViewController {

  internal func performAction(
    for item: ResourceOTPContextualMenuItem
  ) async {
    switch item {
    case .revealOTP:
      await self.revealOTPCode()

    case .copyOTP:
      await self.copyOTPCode()

    case .editOTP:
      await self.editOTP()

    case .deleteOTP:
      await self.deleteOTP()
    }
  }

  internal func revealOTPCode() async {
    await consumingErrors { @MainActor in
      guard let revealOTP = self.revealOTP
      else {
        throw
          InternalInconsistency
          .error("Invalid or missing OTP reveal action!")
      }
      try await self.navigationToSelf.revert(animated: true)
      await revealOTP()
    }
  }

  internal func copyOTPCode() async {
    await consumingErrors {
      try await self.resourceController.fetchSecretIfNeeded()
      let resource: Resource = try await self.resourceController.state.value

      // searching only for the first totp field, can't identify totp otherwise now
      guard let totpSecret: TOTPSecret = resource.firstTOTPSecret
      else {
        throw
          InvalidResourceData
          .error(message: "Invalid or missing TOTP in secret")
      }

      let totpCodeGenerator: TOTPCodeGenerator = try self.features.instance()

			let totp: TOTPValue = totpCodeGenerator.prepare(
				.init(
					resourceID: resourceID,
					secret: totpSecret
				)
			)()
      self.pasteboard.put(totp.otp.rawValue)
      try await self.navigationToSelf.revert(animated: true)
      SnackBarMessageEvent.send("otp.copied.message")
    }
  }

  internal func editOTP() async {
    await consumingErrors { [resourceID] in
      let resourceEditPreparation: ResourceEditPreparation = try features.instance()
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareExisting(resourceID)

      try await self.navigationToSelf.revert()
      try await self.navigationToTOTPEditMenu.perform(
        context: .init(
          editingContext: editingContext
        )
      )
    }
  }

  internal func deleteOTP() async {
    await consumingErrors {
      try await self.navigationToSelf.revert()
      try await navigationToResourceOTPDeleteAlert.perform(
        context: .init(
          resourceID: self.resourceID
        )
      )
    }
  }

  internal func dismiss() async {
    await navigationToSelf.revertCatching()
  }
}
