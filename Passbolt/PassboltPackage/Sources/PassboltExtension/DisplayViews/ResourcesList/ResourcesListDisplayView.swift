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

internal struct ResourcesListDisplayView: ControlledView {

  private let controller: ResourcesListDisplayController

  internal init(
    controller: ResourcesListDisplayController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(self.controller) { state in
      ResourcesListView(
        suggestedResources: state.suggested,
        resources: state.resources,
        refreshAction: self.controller.actionAsync(\.refresh),
        createAction: self.controller.actionOptional(\.createResource),
        resourceTapAction: self.controller.action(\.selectResource),
        resourceMenuAction: self.controller.actionOptional(\.openResourceMenu)
      )
    }
  }
}
