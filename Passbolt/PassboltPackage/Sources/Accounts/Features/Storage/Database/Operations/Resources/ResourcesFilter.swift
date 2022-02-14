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

public struct ResourcesFilter {

  // name/url/username search (AND)
  public var text: String?
  // name search (AND)
  public var name: String?
  // url search (AND)
  public var url: String?
  // username search (AND)
  public var username: String?
  // favorite only search (AND)
  public var favoriteOnly: Bool

  public init(
    text: String? = nil,
    name: String? = nil,
    url: String? = nil,
    username: String? = nil,
    favoriteOnly: Bool = false
  ) {
    self.text = text
    self.name = name
    self.url = url
    self.username = username
    self.favoriteOnly = favoriteOnly
  }

  public var isEmpty: Bool {
    (text?.isEmpty ?? true)
      && (name?.isEmpty ?? true)
      && (url?.isEmpty ?? true)
      && (username?.isEmpty ?? true)
      && !favoriteOnly // favorite only is not an empty filter
  }
}

extension ResourcesFilter: Equatable {}
