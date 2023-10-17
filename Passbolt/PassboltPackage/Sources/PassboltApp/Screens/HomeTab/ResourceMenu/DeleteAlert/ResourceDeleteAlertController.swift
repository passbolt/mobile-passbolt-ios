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

internal struct ResourceDeleteAlertController: AlertController {

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

    self.title = "generic.are.you.sure"
    self.message = .none
    self.actions = [
      .init(
        title: "generic.cancel",
        role: .cancel
      ),
      .init(
        title: "generic.confirm",
        role: .destructive,
        action: {
          Task { @MainActor in
						await consumingErrors {
              try await resourceController.delete()
              SnackBarMessageEvent.send("resource.delete.succeeded")
            }
          }
        }
      ),
    ]
  }
}
