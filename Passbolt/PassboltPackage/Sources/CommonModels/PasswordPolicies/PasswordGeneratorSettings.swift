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

public struct PasswordGeneratorSettings {
  public var length: Int
  public var maskUpper: Bool
  public var maskLower: Bool
  public var maskDigit: Bool
  public var maskParenthesis: Bool
  public var maskEmoji: Bool
  public var maskChar1: Bool
  public var maskChar2: Bool
  public var maskChar3: Bool
  public var maskChar4: Bool
  public var maskChar5: Bool
  public var excludeLookAlikeChars: Bool

  public init(
    length: Int,
    maskUpper: Bool,
    maskLower: Bool,
    maskDigit: Bool,
    maskParenthesis: Bool,
    maskEmoji: Bool,
    maskChar1: Bool,
    maskChar2: Bool,
    maskChar3: Bool,
    maskChar4: Bool,
    maskChar5: Bool,
    excludeLookAlikeChars: Bool
  ) {
    self.length = length
    self.maskUpper = maskUpper
    self.maskLower = maskLower
    self.maskDigit = maskDigit
    self.maskParenthesis = maskParenthesis
    self.maskEmoji = maskEmoji
    self.maskChar1 = maskChar1
    self.maskChar2 = maskChar2
    self.maskChar3 = maskChar3
    self.maskChar4 = maskChar4
    self.maskChar5 = maskChar5
    self.excludeLookAlikeChars = excludeLookAlikeChars
  }
}

// MARK: - Validation

extension PasswordGeneratorSettings {
    private static let PASSWORD_GEN_MIN_PASSWORD_LENGTH = 8
    private static let PASSWORD_GEN_MAX_PASSWORD_LENGTH = 128

    public func validate() throws {
        try self.lengthValidator.ensureValid(self.length)
        try self.maskValidator.ensureValid(self)
    }

    public var lengthValidator: Validator<Int> {
        zip(
            .inRange(
              of: PasswordGeneratorSettings.PASSWORD_GEN_MIN_PASSWORD_LENGTH...PasswordGeneratorSettings.PASSWORD_GEN_MAX_PASSWORD_LENGTH,
                displayable: "error.validation.password.length.invalid"
            )
        )
    }

    public var maskValidator: Validator<PasswordGeneratorSettings> {
      Validator { settings in
          let masks = [
              settings.maskChar1,
              settings.maskChar2,
              settings.maskChar3,
              settings.maskChar4,
              settings.maskChar5,
              settings.maskEmoji,
              settings.maskDigit,
              settings.maskParenthesis,
              settings.maskLower,
              settings.maskUpper
          ]
          if masks.contains(true) {
              return .valid(settings)
          } else {
              return .invalid(
                  settings,
                  error: InvalidValue.notContains(
                      value: settings,
                      displayable: DisplayableString("error.validation.password.mask.empty")
                  )
              )
          }
      }
    }
}
