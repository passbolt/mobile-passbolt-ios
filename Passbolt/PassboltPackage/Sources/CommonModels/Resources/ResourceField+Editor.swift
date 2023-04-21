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

extension ResourceField {

  public enum Editor {

    case undefined
    case textField(encrypted: Bool, required: Bool)
    case longTextField(encrypted: Bool, required: Bool)
    case totp
  }
}

extension ResourceField {

  public var editor: Editor {
    switch (self.name, self.content) {
    case ("description", .string(let encrypted, let required, _, _)):
      return .longTextField(encrypted: encrypted, required: required)

    case (_, .string(let encrypted, let required, _, let maxLength)) where (maxLength ?? 0 > 512): // long fields will be defined as more than 512 characters
      return .longTextField(encrypted: encrypted, required: required)

    case (_, .string(let encrypted, let required, _, _)):
      return .textField(encrypted: encrypted, required: required)

    case (_, .totp):
      return .totp

    case (_, .unknown):
      return .undefined
    }
  }
}
