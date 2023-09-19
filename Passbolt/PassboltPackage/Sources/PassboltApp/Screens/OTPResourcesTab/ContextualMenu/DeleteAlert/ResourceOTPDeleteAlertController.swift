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

internal struct ResourceOTPDeleteAlertController: AlertController {

  internal struct Context {
    internal var resourceID: Resource.ID
  }

  internal let title: Localization.DisplayableString
  internal let message: DisplayableString?
  internal let actions: Array<AlertAction>

  @MainActor init(
    with context: Context,
    using features: Features
  ) throws {
    let features: Features =
      try features.branchIfNeeded(
        scope: ResourceScope.self,
        context: context.resourceID
      )

    let resourceController: ResourceController = try features.instance()

    func deleteOTP() async {
      do {
        let resource: Resource = try await resourceController.state.value
        if resource.type.specification.slug == .totp {
          // for standalone TOTP we delete the resource
          try await resourceController.delete()
        }
        else if let detachedOTPSlug: ResourceSpecification.Slug = resource.detachedOTPSlug {
          let resourceEditPreparation: ResourceEditPreparation = try features.instance()
          let editingContext = try await resourceEditPreparation.prepareExisting(context.resourceID)

          guard
            let detachedType: ResourceType = editingContext.availableTypes.first(where: { type in
              type.specification.slug == detachedOTPSlug
            })
          else {
            throw
              InvalidResourceType
              .error(message: "Attempting to detach OTP from a resource which has none or unavailable detached type!")
          }
          let features: Features =
            try features.branchIfNeeded(
              scope: ResourceEditScope.self,
              context: editingContext
            )

          let resourceEditForm: ResourceEditForm = try features.instance()
          try resourceEditForm.updateType(detachedType)
          try await resourceEditForm.send()
        }
        else {
          throw
            InvalidResourceType
            .error(message: "Attempting to delete OTP in a resource without OTP delete action supported!")
        }

        SnackBarMessageEvent.send("otp.edit.otp.deleted.message")
      }
      catch {
        error.consume()
      }
    }

    self.title = "otp.contextual.menu.delete.confirm.title"
    self.message = "otp.contextual.menu.delete.confirm.message"
    self.actions = [
      .init(
        title: "generic.cancel",
        role: .cancel
      ),
      .init(
        title: "otp.contextual.menu.delete.confirm.action.delete",
        role: .destructive,
        action: {
          Task(priority: .userInitiated) { @MainActor in
            await deleteOTP()
          }
        }
      ),
    ]
  }
}
