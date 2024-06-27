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

public struct PasswordPoliciesDTO {

  public let id: Tagged<PassboltID, Self>
  public var defaultGenerator: PasswordGeneratorType
  public var passwordGeneratorSettings: PasswordGeneratorSettings
  public var passphraseGeneratorSettings: PassphraseGeneratorSettings
  public var externalDictionaryCheck: Bool

  public init(
    id: Tagged<PassboltID, Self>,
    defaultGenerator: PasswordGeneratorType,
    passwordGeneratorSettings: PasswordGeneratorSettings,
    passphraseGeneratorSettings: PassphraseGeneratorSettings,
    externalDictionaryCheck: Bool
  ) {
    self.id = id
    self.defaultGenerator = defaultGenerator
    self.passwordGeneratorSettings = passwordGeneratorSettings
    self.passphraseGeneratorSettings = passphraseGeneratorSettings
    self.externalDictionaryCheck = externalDictionaryCheck
  }
}

extension PasswordPoliciesDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<PasswordPoliciesDTO.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

    // Safely unwrapping PassboltID, crashing with a descriptive error if it fails
    guard let passboltID = PassboltID(uuidString: UUID().uuidString) else {
      unreachable("Failed to create PassboltID with a new UUID string. This should never happen.")
    }
    self.id = Tagged<PassboltID, Self>(rawValue: passboltID)
    self.defaultGenerator =
      try container
      .decode(
        PasswordGeneratorType.self,
        forKey: .defaultGenerator
      )
    self.passwordGeneratorSettings =
      try container
      .decode(
        PasswordGeneratorSettings.self,
        forKey: .passwordGeneratorSettings
      )
    self.passphraseGeneratorSettings =
      try container
      .decode(
        PassphraseGeneratorSettings.self,
        forKey: .passphraseGeneratorSettings
      )
    self.externalDictionaryCheck =
      try container
      .decode(
        Bool.self,
        forKey: .externalDictionaryCheck
      )
  }

  private enum CodingKeys: String, CodingKey {
    case defaultGenerator = "default_generator"
    case passwordGeneratorSettings = "password_generator_settings"
    case passphraseGeneratorSettings = "passphrase_generator_settings"
    case externalDictionaryCheck = "external_dictionary_check"
  }
}
