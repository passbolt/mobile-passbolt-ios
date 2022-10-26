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

extension User.ID {

  public static let mock_1: Self = .init(rawValue: UUID().uuidString)

  public static let mock_2: Self = .init(rawValue: UUID().uuidString)

  public static let mock_ada: Self = .init(rawValue: UUID().uuidString)

  public static let mock_frances: Self = .init(rawValue: UUID().uuidString)
}

extension UserDTO {

  public static let mock_1: Self = .init(
    id: .mock_1,
    active: true,
    deleted: false,
    username: "mock",
    profile: .mock_1,
    gpgKey: .init(
      armoredKey: .init(
        rawValue: "MOCK_1"
      ),
      fingerprint: .init(
        rawValue: "MOCK_1"
      )
    )
  )

  public static let mock_ada: Self = .init(
    id: .mock_ada,
    active: true,
    deleted: false,
    username: "ada@passbolt.com",
    profile: .mock_ada,
    gpgKey: .init(
      armoredKey: .init(
        rawValue: "MOCK_ADA"
      ),
      fingerprint: .init(
        rawValue: "MOCK_ADA"
      )
    )
  )

  public static let mock_frances: Self = .init(
    id: .mock_frances,
    active: true,
    deleted: false,
    username: "frances@passbolt.com",
    profile: .mock_frances,
    gpgKey: .init(
      armoredKey: .init(
        rawValue: "MOCK_FRANCES"
      ),
      fingerprint: .init(
        rawValue: "MOCK_FRANCES"
      )
    )
  )
}

extension UserProfileDTO {

  public static let mock_1: Self = .init(
    firstName: "mock",
    lastName: "1",
    avatar: .init(
      urlString: .mock_apple
    )
  )

  public static let mock_ada: Self = .init(
    firstName: "Ada",
    lastName: "Lovelance",
    avatar: .init(
      urlString: .mock_avatar_ada
    )
  )

  public static let mock_frances: Self = .init(
    firstName: "Frances",
    lastName: "Allen",
    avatar: .init(
      urlString: .mock_avatar_frances
    )
  )
}
