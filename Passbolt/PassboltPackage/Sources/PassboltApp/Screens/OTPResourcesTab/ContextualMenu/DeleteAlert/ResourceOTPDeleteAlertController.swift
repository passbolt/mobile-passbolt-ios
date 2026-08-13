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

/// Asks the operator to confirm removing a TOTP. Nothing but the question: the removal itself is performed by the
/// screen that opened this alert.
///
/// It cannot own the removal, because removing a TOTP from a resource that also holds a password re-encrypts the
/// secret for every recipient and so may open the permission confirmation, whose flow must be retained for as long
/// as its screen may be displayed - and an alert is copied into an `AlertItem` and dropped, retaining nothing.
internal struct ResourceOTPDeleteAlertController: AlertController {

  internal struct Context {
    /// Performs the removal. Invoked on the destructive action only - dismissing or cancelling leaves the resource
    /// untouched.
    internal var onConfirmed: @MainActor @Sendable () async -> Void
  }

  internal let title: Localization.DisplayableString
  internal let message: DisplayableString?
  internal let actions: Array<AlertAction>

  @MainActor init(
    with context: Context,
    using features: Features
  ) throws {
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
        action: { [onConfirmed = context.onConfirmed] in
          Task(priority: .userInitiated) { @MainActor in
            await onConfirmed()
          }
        }
      ),
    ]
  }
}
