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

import SwiftUI

@MainActor
public struct UserGroupListRowView<RightAccessoryView>: View
where RightAccessoryView: View {

  private let chevronVisible: Bool
  private let model: UserGroupListRowViewModel
  private let contentAction: @MainActor () -> Void
  private let rightAction: (@MainActor () -> Void)?
  private let rightAccesory: () -> RightAccessoryView

  public init(
    chevronVisible: Bool = false,
    model: UserGroupListRowViewModel,
    contentAction: @escaping @MainActor () -> Void,
    rightAction: (@MainActor () -> Void)? = .none,
    @ViewBuilder rightAccesory: @escaping () -> RightAccessoryView
  ) {
    self.chevronVisible = chevronVisible
    self.model = model
    self.contentAction = contentAction
    self.rightAction = rightAction
    self.rightAccesory = rightAccesory
  }

  public var body: some View {
    ListRowView(
      chevronVisible: self.chevronVisible,
      title: self.model.name,
      leftAccessory: {
        UserGroupAvatarView()
      },
      contentAction: self.contentAction,
      rightAction: self.rightAction,
      rightAccessory: self.rightAccesory
    )
  }
}

#if DEBUG

internal struct UserGroupListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    UserGroupListRowView(
      model: .init(
        id: .init(),
        name: "Admins"
      ),
      contentAction: {},
      rightAccesory: {
        SelectionIndicator(selected: false)
      }
    )
  }
}
#endif
