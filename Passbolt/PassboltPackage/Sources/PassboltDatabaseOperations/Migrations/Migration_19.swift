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

import Database

// swift-format-ignore: AlwaysUseLowerCamelCase
extension SQLiteMigration {

  internal static var migration_19: Self {
    [
      """
      CREATE TABLE
        passwordGeneratorSettings
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        length INTEGER NOT NULL,
        maskUpper INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskLower INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskDigit INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskParenthesis INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskEmoji INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskChar1 INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskChar2 INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskChar3 INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskChar4 INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        maskChar5 INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        excludeLookAlikeChars INTEGER NOT NULL -- boolean value, 0 interpreted as false, true otherwise
      ); -- create passwordGeneratorSettings table
      """,
      """
      CREATE TABLE
        passphraseGeneratorSettings
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        words INTEGER NOT NULL,
        wordSeparator TEXT NOT NULL,
        wordCase TEXT NOT NULL -- one of [uppercase, lowercase, camelcase]
      ); -- create passphraseGeneratorSettings table
      """,
      """
      CREATE TABLE
        passwordPolicies
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        defaultGenerator TEXT NOT NULL, -- one of [password, passphrase]
        passwordGeneratorSettingsID TEXT NOT NULL,
        passphraseGeneratorSettingsID TEXT NOT NULL,
        externalDictionaryCheck INTEGER NOT NULL, -- boolean value, 0 interpreted as false, true otherwise
        FOREIGN KEY(passwordGeneratorSettingsID) REFERENCES passwordGeneratorSettings(id) ON DELETE CASCADE,
        FOREIGN KEY(passphraseGeneratorSettingsID) REFERENCES passphraseGeneratorSettings(id) ON DELETE CASCADE
      ); -- create passwordPolicies table
      """,
      // - version bump - //
      """
      PRAGMA user_version = 20; -- persistent, used to track schema version
      """,
    ]
  }
}
