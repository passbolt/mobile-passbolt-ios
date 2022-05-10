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

#if DEBUG

import struct Foundation.Data

extension Generator where Value == String {

  public static func randomFirstName(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "Ada",
      "Frances",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomLastName(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "Lovelance",
      "Allen",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomEmail(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "ada@passbolt.com",
      "frances@passbolt.com",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomArmoredGPGPublicKey(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      """
      -----BEGIN PGP PUBLIC KEY BLOCK-----

      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
      =Kwft
      -----END PGP PUBLIC KEY BLOCK-----
      """,
      """
      -----BEGIN PGP PUBLIC KEY BLOCK-----

      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
      =82jm
      -----END PGP PUBLIC KEY BLOCK-----
      """,
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomKeyFingerprint(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "KEYFINGERPRINT",
      "OTHER_KEYFINGERPRINT",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomURL(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "https://passbolt.com/mock/path",
      "https://passbolt.com/mock/path/even/more/nested",
      "https://passbolt.com/mock/path?with=query",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomUserGroupName(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "UserGroup",
      "PassboltGroup",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomResourceName(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "SecretPassword",
      "EvenMoreSecretPassword",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomLongText(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "Lorem ipsum dolor sit amet...",
      "Ipsum sit lorem amet dolor???",
    ]
    .randomNonEmptyElementGenerator(
      using: randomnessGenerator
    )
  }

  public static func randomFolderName(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    [
      "FolderName",
      "DifferentFolderName",
    ]
    .randomNonEmptyElementGenerator(using: randomnessGenerator)
  }
}

extension Generator where Value == Data? {

  public static func randomAvatarImage(
    using randomnessGenerator: RandomnessGenerator = .sharedDebugRandomSource
  ) -> Self {
    ([
      nil,
      Data(
        base64Encoded: """
        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
        """,
        options: .ignoreUnknownCharacters
      ),
      Data(
        base64Encoded: """
        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
        """,
        options: .ignoreUnknownCharacters
      )
    ] as Array<Data?>)
    .randomNonEmptyElementGenerator(using: randomnessGenerator)
  }
}
#endif
