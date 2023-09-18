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

extension Account {

  public static let mock_ada: Self = .init(
    localID: .mock_ada,
    domain: .mock_passbolt,
    userID: .mock_ada,
    fingerprint: "FINGERPRINT_MOCK_ADA"
  )

  public static let mock_frances: Self = .init(
    localID: .mock_frances,
    domain: .mock_passbolt_alt,
    userID: .mock_frances,
    fingerprint: "FINGERPRINT_MOCK_FRANCES"
  )

  public static let mock_static: Self = .init(
    localID: "3EDBC019-BFF4-49AF-B8DF-DD283423E8F3",
    domain: .mock_passbolt_alt,
    userID: .init(uuidString: "F8B8F377-8045-49A1-BAAA-D04270406675")!,
    fingerprint: "FINGERPRINT_MOCK_FRANCES"
  )
}

extension Account.LocalID {

  public static let mock_ada: Self = .init(rawValue: "9514E95F-1A1F-40E1-965D-B596AF797F82")

  public static let mock_frances: Self = .init(rawValue: "9AF7F1CC-8443-4D36-AFF3-431AA8347488")

  public static let mock_1: Self = .init(rawValue: "611A8428-13DA-4EEF-87FC-6567C73CE4FC")
}
