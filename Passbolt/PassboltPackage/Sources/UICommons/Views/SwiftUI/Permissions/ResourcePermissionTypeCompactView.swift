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
public struct ResourcePermissionTypeCompactView: View {

  private let permissionTypeLabel: DisplayableString

  public init(
    permissionType: PermissionType
  ) {
    switch permissionType {
    case .read:
      self.permissionTypeLabel = .localized(key: "resource.permission.type.read.label")

    case .write:
      self.permissionTypeLabel = .localized(key: "resource.permission.type.write.label")

    case .owner:
      self.permissionTypeLabel = .localized(key: "resource.permission.type.own.label")
    }
  }

  public var body: some View {
    Text(
      displayable: self.permissionTypeLabel
    )
    .text(
      font: .inter(
        ofSize: 12,
        weight: .regular
      ),
      color: .passboltPrimaryText
    )
    .padding(10)
    .backgroundColor(.passboltSecondaryGray)
    .cornerRadius(5)
  }
}

#if DEBUG

internal struct ResourcePermissionTypeView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourcePermissionTypeCompactView(
      permissionType: .read
    )
    ResourcePermissionTypeCompactView(
      permissionType: .write
    )
    ResourcePermissionTypeCompactView(
      permissionType: .owner
    )
  }
}
#endif
