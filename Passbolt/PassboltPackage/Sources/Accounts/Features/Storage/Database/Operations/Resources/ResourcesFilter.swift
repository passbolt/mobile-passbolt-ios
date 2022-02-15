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

public struct ResourcesFilter {

  // ordering of results
  public var sorting: ResourcesSorting
  // name/url/username search (AND) - empty ignores this parameter
  public var text: String
  // name search (AND) - empty ignores this parameter
  public var name: String
  // url search (AND) - empty ignores this parameter
  public var url: String
  // username search (AND) - empty ignores this parameter
  public var username: String
  // favorite only search (AND)
  public var favoriteOnly: Bool
  // included permissions search (AND) - empty ignores this parameter
  public var permissions: Set<ResourcePermission>

  public init(
    sorting: ResourcesSorting = .nameAlphabetically,
    text: String = .init(),
    name: String = .init(),
    url: String = .init(),
    username: String = .init(),
    favoriteOnly: Bool = false,
    permissions: Set<ResourcePermission> = .init()
  ) {
    self.sorting = sorting
    self.text = text
    self.name = name
    self.url = url
    self.username = username
    self.favoriteOnly = favoriteOnly
    self.permissions = permissions
  }

  public var isEmpty: Bool {
    text.isEmpty
      && name.isEmpty
      && url.isEmpty
      && username.isEmpty
      && !favoriteOnly  // favorite only is not an empty filter
      && permissions.isEmpty
  }
}

extension ResourcesFilter: Equatable {}
