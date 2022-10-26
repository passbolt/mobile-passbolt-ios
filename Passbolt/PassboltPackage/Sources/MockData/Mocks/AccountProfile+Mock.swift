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

import Accounts

extension AccountProfile {

  public static let mock_ada: Self = .init(
    accountID: .mock_ada,
    label: "Ada Lovelance",
    username: "ada@passbolt.com",
    firstName: "Ada",
    lastName: "Lovelance",
    avatarImageURL: .mock_avatar_ada
  )

  public static let mock_frances: Self = .init(
    accountID: .mock_frances,
    label: "Frances Allen",
    username: "frances@passbolt.com",
    firstName: "Frances",
    lastName: "Allen",
    avatarImageURL: .mock_avatar_frances
  )
}

extension AccountWithProfile {

  public static let mock_ada: Self = .init(
    localID: .mock_ada,
    userID: .mock_ada,
    domain: .mock_passbolt,
    label: "Ada Lovelance",
    username: "ada@passbolt.com",
    firstName: "Ada",
    lastName: "Lovelance",
    avatarImageURL: .mock_avatar_ada,
    fingerprint: "FINGERPRINT_MOCK_ADA"
  )

  public static let mock_frances: Self = .init(
    localID: .mock_frances,
    userID: .mock_frances,
    domain: .mock_passbolt_alt,
    label: "Frances Allen",
    username: "frances@passbolt.com",
    firstName: "Frances",
    lastName: "Allen",
    avatarImageURL: .mock_avatar_frances,
    fingerprint: "FINGERPRINT_MOCK_FRANCES"
  )
}
