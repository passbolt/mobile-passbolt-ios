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

extension PasswordPoliciesFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Void,
    connection: SQLiteConnection
  ) throws -> PasswordPoliciesDSV {
    try connection
      .fetchFirst(
        using: .statement(
          """
          SELECT
            passwordPolicies.id AS id,
            passwordPolicies.defaultGenerator AS defaultGenerator,
            passwordPolicies.externalDictionaryCheck AS externalDictionaryCheck,
            passwordGeneratorSettings.length AS length,
            passwordGeneratorSettings.maskUpper AS maskUpper,
            passwordGeneratorSettings.maskLower AS maskLower,
            passwordGeneratorSettings.maskDigit AS maskDigit,
            passwordGeneratorSettings.maskParenthesis AS maskParenthesis,
            passwordGeneratorSettings.maskEmoji AS maskEmoji,
            passwordGeneratorSettings.maskChar1 AS maskChar1,
            passwordGeneratorSettings.maskChar2 AS maskChar2,
            passwordGeneratorSettings.maskChar3 AS maskChar3,
            passwordGeneratorSettings.maskChar4 AS maskChar4,
            passwordGeneratorSettings.maskChar5 AS maskChar5,
            passwordGeneratorSettings.excludeLookAlikeChars AS excludeLookAlikeChars,
            passphraseGeneratorSettings.words AS words,
            passphraseGeneratorSettings.wordSeparator AS wordSeparator,
            passphraseGeneratorSettings.wordCase AS wordCase
          FROM
            passwordPolicies
          JOIN
            passwordGeneratorSettings
          ON
            passwordPolicies.passwordGeneratorSettingsID = passwordGeneratorSettings.id
          JOIN
            passphraseGeneratorSettings
          ON
            passwordPolicies.passphraseGeneratorSettingsID = passphraseGeneratorSettings.id
          LIMIT 1
          ;
          """
        )
      ) { dataRow -> PasswordPoliciesDSV in
        guard
          let policiesID: Tagged<PassboltID, PasswordPoliciesDSV> = dataRow.id,
          let defaultGenerator: String = dataRow.defaultGenerator,
          let generatorType: PasswordGeneratorType = .init(rawValue: defaultGenerator),
          let externalDictionaryCheck: Int = dataRow.externalDictionaryCheck,
          let length: Int = dataRow.length,
          let maskUpper: Int = dataRow.maskUpper,
          let maskLower: Int = dataRow.maskLower,
          let maskDigit: Int = dataRow.maskDigit,
          let maskParenthesis: Int = dataRow.maskParenthesis,
          let maskEmoji: Int = dataRow.maskEmoji,
          let maskChar1: Int = dataRow.maskChar1,
          let maskChar2: Int = dataRow.maskChar2,
          let maskChar3: Int = dataRow.maskChar3,
          let maskChar4: Int = dataRow.maskChar4,
          let maskChar5: Int = dataRow.maskChar5,
          let excludeLookAlikeChars: Int = dataRow.excludeLookAlikeChars,
          let words: Int = dataRow.words,
          let wordSeparator: String = dataRow.wordSeparator,
          let wordCase: String = dataRow.wordCase,
          let wordCaseValue: PasswordGeneratorCase = .init(rawValue: wordCase)
        else {
          throw
            DatabaseIssue
            .error(
              underlyingError:
                DatabaseDataInvalid
                .error(for: PasswordPoliciesDSV.self)
            )
            .recording(dataRow, for: "dataRow")
        }

        return PasswordPoliciesDSV(
          id: policiesID,
          defaultGenerator: generatorType,
          passwordGeneratorSettings: .init(
            length: length,
            maskUpper: maskUpper != 0,
            maskLower: maskLower != 0,
            maskDigit: maskDigit != 0,
            maskParenthesis: maskParenthesis != 0,
            maskEmoji: maskEmoji != 0,
            maskChar1: maskChar1 != 0,
            maskChar2: maskChar2 != 0,
            maskChar3: maskChar3 != 0,
            maskChar4: maskChar4 != 0,
            maskChar5: maskChar5 != 0,
            excludeLookAlikeChars: excludeLookAlikeChars != 0
          ),
          passphraseGeneratorSettings: .init(
            words: words,
            wordSeparator: wordSeparator,
            wordCase: wordCaseValue
          ),
          externalDictionaryCheck: externalDictionaryCheck != 0
        )
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltPasswordPoliciesFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: PasswordPoliciesFetchDatabaseOperation.self,
        execute: PasswordPoliciesFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
