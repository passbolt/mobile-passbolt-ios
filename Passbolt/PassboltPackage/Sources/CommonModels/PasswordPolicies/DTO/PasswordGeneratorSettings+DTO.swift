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

extension PasswordGeneratorSettings: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<PasswordGeneratorSettings.CodingKeys> = try decoder.container(
      keyedBy: CodingKeys.self
    )

    self.length =
      try container
      .decode(
        Int.self,
        forKey: .length
      )
    self.maskUpper =
      try container
      .decode(
        Bool.self,
        forKey: .maskUpper
      )
    self.maskUpper =
      try container
      .decode(
        Bool.self,
        forKey: .maskUpper
      )
    self.maskLower =
      try container
      .decode(
        Bool.self,
        forKey: .maskLower
      )
    self.maskDigit =
      try container
      .decode(
        Bool.self,
        forKey: .maskDigit
      )
    self.maskParenthesis =
      try container
      .decode(
        Bool.self,
        forKey: .maskParenthesis
      )
    self.maskEmoji =
      try container
      .decode(
        Bool.self,
        forKey: .maskEmoji
      )
    self.maskChar1 =
      try container
      .decode(
        Bool.self,
        forKey: .maskChar1
      )
    self.maskChar2 =
      try container
      .decode(
        Bool.self,
        forKey: .maskChar2
      )
    self.maskChar3 =
      try container
      .decode(
        Bool.self,
        forKey: .maskChar3
      )
    self.maskChar4 =
      try container
      .decode(
        Bool.self,
        forKey: .maskChar4
      )
    self.maskChar5 =
      try container
      .decode(
        Bool.self,
        forKey: .maskChar5
      )
    self.excludeLookAlikeChars =
      try container
      .decode(
        Bool.self,
        forKey: .excludeLookAlikeChars
      )
  }

  private enum CodingKeys: String, CodingKey {
    case length = "length"
    case maskUpper = "mask_upper"
    case maskLower = "mask_lower"
    case maskDigit = "mask_digit"
    case maskParenthesis = "mask_parenthesis"
    case maskEmoji = "mask_emoji"
    case maskChar1 = "mask_char1"
    case maskChar2 = "mask_char2"
    case maskChar3 = "mask_char3"
    case maskChar4 = "mask_char4"
    case maskChar5 = "mask_char5"
    case excludeLookAlikeChars = "exclude_look_alike_chars"
  }
}
