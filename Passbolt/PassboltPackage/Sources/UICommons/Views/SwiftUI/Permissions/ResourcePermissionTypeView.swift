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

import CommonModels
import SwiftUI

@MainActor
public struct ResourcePermissionTypeView: View {

  private let permissionIcon: Image
  private let permissionLabel: DisplayableString

  public init(
    permission: Permission
  ) {
    switch permission {
    case .read:
      self.permissionIcon = .init(named: .permissionReadIcon)
      self.permissionLabel = .localized(key: "resource.permission.type.read.label")

    case .write:
      self.permissionIcon = .init(named: .permissionWriteIcon)
      self.permissionLabel = .localized(key: "resource.permission.type.write.label")

    case .owner:
      self.permissionIcon = .init(named: .permissionOwnIcon)
      self.permissionLabel = .localized(key: "resource.permission.type.own.label")
    }
  }

  public var body: some View {
    HStack(spacing: 0) {
      self.permissionIcon
        .resizable()
        .aspectRatio(1, contentMode: .fit)
        .frame(
          width: 24,
          height: 24
        )
        .foregroundColor(.passboltPrimaryText)
      Text(
        displayable: self.permissionLabel
      )
      .text(
        font: .inter(
          ofSize: 14,
          weight: .semibold
        ),
        color: .passboltPrimaryText
      )
      .padding(8)
    }
  }
}

#if DEBUG

internal struct ResourcePermissionTypeView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourcePermissionTypeView(
      permission: .read
    )
    ResourcePermissionTypeView(
      permission: .write
    )
    ResourcePermissionTypeView(
      permission: .owner
    )
  }
}
#endif
