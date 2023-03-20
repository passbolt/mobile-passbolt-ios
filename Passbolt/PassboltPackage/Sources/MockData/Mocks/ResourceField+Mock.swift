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

extension ResourceField {

  public static let name: Self = .init(
    name: "name",
    content: .string(
      encrypted: false,
      required: true,
      minLength: 0,
      maxLength: .none
    )
  )

  public static let username: Self = .init(
    name: "username",
    content: .string(
      encrypted: false,
      required: false,
      minLength: .none,
      maxLength: .none
    )
  )

  public static let uri: Self = .init(
    name: "uri",
    content: .string(
      encrypted: false,
      required: false,
      minLength: .none,
      maxLength: .none
    )
  )

  public static let password: Self = .init(
    name: "password",
    content: .string(
      encrypted: true,
      required: true,
      minLength: .none,
      maxLength: .none
    )
  )

  public static let description: Self = .init(
    name: "description",
    content: .string(
      encrypted: false,
      required: false,
      minLength: .none,
      maxLength: .none
    )
  )

  public static let descriptionEncrypted: Self = .init(
    name: "description",
    content: .string(
      encrypted: true,
      required: false,
      minLength: .none,
      maxLength: .none
    )
  )

  public static let totp: Self = .init(
    name: "totp",
    content: .totp(required: true)
  )
}
