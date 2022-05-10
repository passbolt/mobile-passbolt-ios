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

  // ordering of results
  public var sorting: ResourceFoldersSorting
  // text search (AND) - empty ignores this parameter
  public var text: String
  // current folder contents search (AND) - search on folders root on no value
  // current folder itself won't appear in results
  public var folderID: ResourceFolder.ID?
  // folder content flattening from current folderID
  // false - filters only within current folderID direct descendants
  // true - filters recursively within current folderID and all its subfolders
  public var flattenContent: Bool
  // included permissions search (AND) - empty ignores this parameter
  public var permissions: Set<PermissionType>

  public init(
    sorting: ResourceFoldersSorting,
    text: String = .init(),
    folderID: ResourceFolder.ID?,
    flattenContent: Bool = false,
    permissions: Set<PermissionType> = .init()
  ) {
    self.sorting = sorting
    self.text = text
    self.folderID = folderID
    self.flattenContent = flattenContent
    self.permissions = permissions
  }
}

extension ResourceFoldersFilter: Equatable {}
