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

extension Resource {

  public static let mock_1: Self = {
    var mock: Resource = .init(
      id: .mock_1,
      path: .init(),
      favoriteID: .none,
      type: .mock_1,
      permission: .owner,
      tags: [
        .init(
          id: .mock_1,
          slug: .init(rawValue: "mock_1"),
          shared: false
        )
      ],
      permissions: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        )
      ],
      modified: .init(rawValue: 0)
    )
    mock.name = .string("Mock_1")
    mock.password = .string("R@nD0m")
    return mock
  }()
  
  public static let mock_2: Self = {
    var mock: Resource = .init(
      id: .mock_2,
      path: .init(),
      favoriteID: .none,
      type: .mock_2,
      permission: .owner,
      tags: [
        .init(
          id: .mock_1,
          slug: .init(rawValue: "mock_1"),
          shared: false
        )
      ],
      permissions: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_2
        )
      ],
      modified: .init(rawValue: 0)
    )
    mock.name = .string("Mock_1")
    mock.password = .string("R@nD0m")
    return mock
  }()
}

