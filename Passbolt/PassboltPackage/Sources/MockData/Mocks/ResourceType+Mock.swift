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

extension ResourceType.ID {

  public static let mock_1: Self = .init(uuidString: "F9B39DCA-CD93-4CD4-B91D-8AAE7B7AA813")!

  public static let mock_2: Self = .init(uuidString: "59C8F6AE-AEE8-4905-983B-795A675EE0E2")!

  public static let mock_3: Self = .init(uuidString: "C3673B6B-B918-4BF4-9162-0178B8D18399")!

  public static let mock_4: Self = .init(uuidString: "A6626564-8CE2-4FC0-870C-5C299F04AB0C")!
}

extension ResourceSpecification.Slug {

  public static let mock_1: Self = .init(rawValue: "mock_1")

  public static let mock_2: Self = .init(rawValue: "mock_2")
}

extension ResourceType {

  public static let mock_1: Self = .init(
    id: .mock_1,
    slug: .mock_1,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(maxLength: 1024),
        required: true,
        encrypted: false
      )
    ],
    secretFields: [
      .init(
        path: \.secret.password,
        name: "password",
        content: .string(maxLength: 4096),
        required: true,
        encrypted: true
      )
    ]
  )

  public static let mock_2: Self = .init(
    id: .mock_2,
    slug: .mock_2,
    metaFields: [
      .init(
        path: \.meta.name,
        name: "name",
        content: .string(maxLength: 1024),
        required: true,
        encrypted: false
      )
    ],
    secretFields: [
      .init(
        path: \.secret.password,
        name: "password",
        content: .string(maxLength: 4096),
        required: true,
        encrypted: true
      )
    ]
  )

  public static let mock_default: Self = .init(
    id: .mock_3,
    slug: .passwordWithDescription
  )

  public static let mock_totp: Self = .init(
    id: .mock_4,
    slug: .totp
  )
}
