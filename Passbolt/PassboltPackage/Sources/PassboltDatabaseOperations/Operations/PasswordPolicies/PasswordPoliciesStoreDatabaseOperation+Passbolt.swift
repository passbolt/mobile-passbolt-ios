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
import DatabaseOperations
import FeatureScopes
import Session

// MARK: - Implementation

extension PasswordPoliciesStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: PasswordPoliciesDTO,
    connection: SQLiteConnection
  ) throws {
    //Validate passwordGeneratorSettings before insertion
    try input.passwordGeneratorSettings.validate()
    // Delete currently stored password generator settings
    try connection.execute("DELETE FROM passwordGeneratorSettings")
    // Delete currently stored passphrase generator settings
    try connection.execute("DELETE FROM passphraseGeneratorSettings")
    // Delete currently stored password policy
    try connection.execute("DELETE FROM passwordPolicies")

    // Insert or update passwordGeneratorSettings
    try connection.execute(
      .statement(
        """
        INSERT INTO
          passwordGeneratorSettings(
            id,
            length,
            maskUpper,
            maskLower,
            maskDigit,
            maskParenthesis,
            maskEmoji,
            maskChar1,
            maskChar2,
            maskChar3,
            maskChar4,
            maskChar5,
            excludeLookAlikeChars
          )
        VALUES
          (
            ?1,
            ?2,
            ?3,
            ?4,
            ?5,
            ?6,
            ?7,
            ?8,
            ?9,
            ?10,
            ?11,
            ?12,
            ?13
          )
        ON CONFLICT
          (
            id
          )
        DO UPDATE SET
          length=?1,
          maskUpper=?2,
          maskLower=?3,
          maskDigit=?4,
          maskParenthesis=?5,
          maskEmoji=?6,
          maskChar1=?7,
          maskChar2=?8,
          maskChar3=?9,
          maskChar4=?10,
          maskChar5=?11,
          excludeLookAlikeChars=?12
        ;
        """,
        arguments: input.id,
        input.passwordGeneratorSettings.length,
        input.passwordGeneratorSettings.maskUpper ? 1 : 0,
        input.passwordGeneratorSettings.maskLower ? 1 : 0,
        input.passwordGeneratorSettings.maskDigit ? 1 : 0,
        input.passwordGeneratorSettings.maskParenthesis ? 1 : 0,
        input.passwordGeneratorSettings.maskEmoji ? 1 : 0,
        input.passwordGeneratorSettings.maskChar1 ? 1 : 0,
        input.passwordGeneratorSettings.maskChar2 ? 1 : 0,
        input.passwordGeneratorSettings.maskChar3 ? 1 : 0,
        input.passwordGeneratorSettings.maskChar4 ? 1 : 0,
        input.passwordGeneratorSettings.maskChar5 ? 1 : 0,
        input.passwordGeneratorSettings.excludeLookAlikeChars ? 1 : 0
      )
    )


    // Insert or update passphraseGeneratorSettings
    try connection.execute(
      .statement(
        """
        INSERT INTO
          passphraseGeneratorSettings(
            id,
            words,
            wordSeparator,
            wordCase
          )
        VALUES
          (
            ?1,
            ?2,
            ?3,
            ?4
          )
        ON CONFLICT
          (
            id
          )
        DO UPDATE SET
          words=?1,
          wordSeparator=?2,
          wordCase=?3
        ;
        """,
        arguments: input.id,
        input.passphraseGeneratorSettings.words,
        input.passphraseGeneratorSettings.wordSeparator,
        input.passphraseGeneratorSettings.wordCase.rawValue
      )
    )
    // Insert or update passwordPolicies
    try connection.execute(
      .statement(
        """
        INSERT INTO
          passwordPolicies(
            id,
            defaultGenerator,
            passwordGeneratorSettingsID,
            passphraseGeneratorSettingsID,
            externalDictionaryCheck
          )
        VALUES
          (
            ?1,
            ?2,
            ?3,
            ?4,
            ?5
          )
        ON CONFLICT
          (
            id
          )
        DO UPDATE SET
          defaultGenerator=?2,
          passwordGeneratorSettingsID=?3,
          passphraseGeneratorSettingsID=?4,
          externalDictionaryCheck=?5
        ;
        """,
        arguments: input.id,
        input.defaultGenerator.rawValue,
        input.id,
        input.id,
        input.externalDictionaryCheck ? 1 : 0
      )
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltPasswordPoliciesStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: PasswordPoliciesStoreDatabaseOperation.self,
        execute: PasswordPoliciesStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
