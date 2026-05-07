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

import Features
import Foundation
import OSFeatures

import func Darwin.log

public struct SecretGenerator: Sendable {

  public typealias Configuration = PasswordPoliciesDSV

  public var generate: @Sendable (Configuration) throws -> String
  public var entropy: @Sendable (String, Configuration) -> Entropy
}

extension SecretGenerator: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: SecretGenerator {
    .init(
      generate: unimplemented1(),
      entropy: unimplemented2()
    )
  }
  #endif

  @MainActor public static func load(
    using features: Features
  ) throws -> Self {
    let passwordGenerator: PasswordGenerator = try features.instance()
    let passphraseGenerator: PassphraseGenerator = try features.instance()

    @Sendable
    func generate(using configuration: Configuration) throws -> String {
      switch configuration.defaultGenerator {
      case .password:
        return try passwordGenerator.generate(configuration.passwordGeneratorSettings)
      case .passphrase:
        return try passphraseGenerator.generate(configuration.passphraseGeneratorSettings)
      }
    }

    @Sendable
    func entropy(_ secret: String, _ configuration: Configuration) -> Entropy {
      switch configuration.defaultGenerator {
      case .password:
        return passwordGenerator.entropy(secret, configuration.passwordGeneratorSettings)
      case .passphrase:
        return passphraseGenerator.entropy(secret, configuration.passphraseGeneratorSettings)
      }
    }

    return .init(
      generate: generate(using:),
      entropy: entropy
    )
  }
}

extension SecretGenerator.Configuration {

  public static let `default`: Self = .init(
    id: .init(),
    defaultGenerator: .password,
    passwordGeneratorSettings: .init(
      length: 18,
      maskUpper: true,
      maskLower: true,
      maskDigit: true,
      maskParenthesis: false,
      maskEmoji: false,
      maskChar1: true,
      maskChar2: true,
      maskChar3: true,
      maskChar4: true,
      maskChar5: true,
      excludeLookAlikeChars: false
    ),
    passphraseGeneratorSettings: .init(
      words: 3,
      wordSeparator: " ",
      wordCase: .lowercase
    ),
    externalDictionaryCheck: false
  )
}

extension FeaturesRegistry {

  internal mutating func useSecretGenerator() {
    self.use(
      .lazyLoaded(
        SecretGenerator.self,
        load: SecretGenerator.load(using:)
      )
    )
  }
}
