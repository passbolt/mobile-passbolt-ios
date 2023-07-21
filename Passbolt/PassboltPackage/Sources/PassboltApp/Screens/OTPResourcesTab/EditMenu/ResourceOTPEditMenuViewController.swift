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

internal final class ResourceOTPEditMenuViewController: ViewController {

  internal struct Context {

    internal var editingContext: ResourceEditingContext
    internal var showMessage: @MainActor (SnackBarMessage) -> Void

    internal init(
      editingContext: ResourceEditingContext,
      showMessage: @escaping @MainActor (SnackBarMessage) -> Void
    ) {
      self.editingContext = editingContext
      self.showMessage = showMessage
    }
  }

  internal let creatingNew: Bool

  private let resourceEditForm: ResourceEditForm
  private let navigationToSelf: NavigationToResourceOTPEditMenu
  private let navigationToQRCodeCreateOTPView: NavigationToOTPScanning
  private let navigationToOTPEditForm: NavigationToOTPEditForm

  private let context: Context

  private let features: Features

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    let features: Features =
      features.branchIfNeeded(
        scope: ResourceEditScope.self,
        context: context.editingContext
      ) ?? features.takeOwned()
    self.features = features

    self.creatingNew = context.editingContext.editedResource.isLocal || !context.editingContext.editedResource.hasTOTP

    self.context = context

    self.navigationToSelf = try features.instance()
    self.navigationToQRCodeCreateOTPView = try features.instance()
    self.navigationToOTPEditForm = try features.instance()

    self.resourceEditForm = try features.instance()
  }
}

extension ResourceOTPEditMenuViewController {

  internal func editFromQRCode() async {
    do {
      try await navigationToSelf.revert()
      let editedResource: Resource = try await self.resourceEditForm.state.value
      guard
        let attachedOTPSlug: ResourceSpecification.Slug = editedResource.attachedOTPSlug,
        let attachType: ResourceType = context.editingContext.availableTypes.first(where: {
          $0.specification.slug == attachedOTPSlug
        }),
        let totpPath: ResourceType.FieldPath = attachType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        throw
          InvalidResourceType
          .error(message: "Attempting to attach OTP to a resource which has none or unavailable attached type!")
      }

      if editedResource.type != attachType {
        try self.resourceEditForm.updateType(attachType)
      }  // else - use current type

      try await self.navigationToQRCodeCreateOTPView.perform(
        context: .init(
          totpPath: totpPath,
          showMessage: self.context.showMessage
        )
      )
    }
    catch {
      error.logAndShow(using: self.context.showMessage)
    }
  }

  internal func editManually() async {
    do {
      try await navigationToSelf.revert()
      let editedResource: Resource = try await self.resourceEditForm.state.value
      guard
        let attachedOTPSlug: ResourceSpecification.Slug = editedResource.attachedOTPSlug,
        let attachType: ResourceType = context.editingContext.availableTypes.first(where: {
          $0.specification.slug == attachedOTPSlug
        }),
        let totpPath: ResourceType.FieldPath = attachType.fieldSpecification(for: \.firstTOTP)?.path
      else {
        throw
          InvalidResourceType
          .error(message: "Attempting to attach OTP to a resource which has none or unavailable attached type!")
      }

      if editedResource.type != attachType {
        try self.resourceEditForm.updateType(attachType)
      }  // else - use current type

      try await self.navigationToOTPEditForm.perform(
        context: .init(
          totpPath: totpPath,
          showMessage: self.context.showMessage
        )
      )
    }
    catch {
      error.logAndShow(using: self.context.showMessage)
    }
  }

  internal func dismiss() async {
    await navigationToSelf.revertCatching()
  }
}
