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

import Commons

extension ResourceField {

  public var validator: Validator<ResourceFieldValue?> {
    switch self.content {
    case let .string(_, required, minLength, maxLength):
      return .init { (value: ResourceFieldValue?) in
        guard let value: ResourceFieldValue
        else {
          if required {
            return .invalid(
              value,
              error: InvalidValue.null(
                value: value,
                displayable: "resource.form.field.error.empty"
              )
            )
          }
          else {
            return .valid(value)
          }
        }

        guard case let .string(string) = value
        else {
          return .invalid(
            value,
            error: InvalidValue.wrongType(
              value: value,
              displayable: "resource.from.field.error.invalid.value"
            )
          )
        }

        guard !string.isEmpty || !required,
          string.count >= (minLength ?? 0),
          // even if there is no requirement for max length we are limiting it with
          // some high value to prevent too big values
          string.count <= (maxLength ?? 1_000_000)
        else {
          return .invalid(
            value,
            error: InvalidValue.invalid(
              value: value,
              displayable: "resource.form.field.error.invalid"
            )
          )
        }

        return .valid(value)
      }

    case let .totp(required):
      return .init { (value: ResourceFieldValue?) in
        guard let value: ResourceFieldValue
        else {
          if required {
            return .invalid(
              value,
              error: InvalidValue.null(
                value: value,
                displayable: "resource.form.field.error.empty"
              )
            )
          }
          else {
            return .valid(value)
          }
        }

        guard case let .otp(.totp(secret, _, digits, period)) = value
        else {
          return .invalid(
            value,
            error: InvalidValue.wrongType(
              value: value,
              displayable: "resource.from.field.error.invalid.value"
            )
          )
        }

        guard
          period > 0,
          digits >= 6,
          digits <= 8,
          !secret.isEmpty
        else {
          return .invalid(
            value,
            error: InvalidValue.invalid(
              value: value,
              displayable: "resource.form.field.error.invalid"
            )
          )
        }

        return .valid(value)
      }

    case .unknown(_, let required):
      return .init { (value: ResourceFieldValue?) in
        switch value {
        case .unknown(.null):
          if required {
            return .invalid(
              value,
              error: InvalidValue.null(
                value: value,
                displayable: "resource.form.field.error.empty"
              )
            )
          }
          else {
            return .valid(value)
          }

        case .encrypted, .unknown:
          return .valid(value)

        case _:
          return .invalid(
            value,
            error: InvalidValue.invalid(
              value: value,
              displayable: "resource.form.field.error.invalid"
            )
          )
        }
      }
    }
  }
}
