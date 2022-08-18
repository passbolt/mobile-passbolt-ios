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

public struct ResourceFoldersFilter {

  public var sorting: ResourcesSorting
  public var text: String
  public var folderID: ResourceFolder.ID?  // none means root
  public var flattenContent: Bool
  public var permissions: OrderedSet<PermissionType>

  public init(
    sorting: ResourcesSorting,
    text: String,
    folderID: ResourceFolder.ID?,
    flattenContent: Bool,
    permissions: OrderedSet<PermissionType>
  ) {
    self.sorting = sorting
    self.text = text
    self.folderID = folderID
    self.flattenContent = flattenContent
    self.permissions = permissions
  }
}

extension ResourceFoldersFilter: Hashable {}
