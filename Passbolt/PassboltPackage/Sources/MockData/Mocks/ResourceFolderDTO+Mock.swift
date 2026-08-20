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
import Commons

extension ResourceFolderDTO {

  /// A root folder owned by the operator, carrying no permissions of its own - the shape the folders fetch
  /// returns for an account whose folders are all its own.
  ///
  /// Each call takes a fresh id, so a set built from this is distinguishable by both id and name. Tests of
  /// the paginated folders fetch rely on that: it merges pages and dedups by id, and asserts the merged set
  /// against the folders the server was given.
  public static func mock(named name: String) -> Self {
    .init(
      id: .init(),
      parentID: .none,
      name: name,
      permission: .owner,
      permissions: .init()
    )
  }

  /// `count` distinct folders, named by index - for tests that care about how many folders a page holds
  /// rather than what is in them.
  public static func mocks(count: Int) -> Array<Self> {
    (0 ..< count).map { (index: Int) -> Self in .mock(named: "folder-\(index)") }
  }
}

extension ResourceFolderDTO: MockBuilder {}
