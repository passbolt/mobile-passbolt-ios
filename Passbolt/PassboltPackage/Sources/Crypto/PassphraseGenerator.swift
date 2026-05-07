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
import OSFeatures

import func Darwin.log

internal struct PassphraseGenerator: Sendable {

  internal var generate: @Sendable (PassphraseGeneratorSettings) throws -> String
  internal var entropy: @Sendable (String, PassphraseGeneratorSettings) -> Entropy
}

extension PassphraseGenerator: LoadableFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    .init(
      generate: unimplemented1(),
      entropy: unimplemented2()
    )
  }
  #endif

  @MainActor internal static func load(
    using features: Features
  ) -> PassphraseGenerator {

    let randomness: OSRandomness = features.instance()

    @Sendable
    func generatePassphrase(_ settings: PassphraseGeneratorSettings) throws -> String {
      let wordlist: Array<String> = EFFWordlist.words
      guard settings.words > 0, !wordlist.isEmpty
      else { throw GenerationError.error() }

      var rng: OSRandomness = randomness
      var selectedWords: Array<String> = .init()
      for _ in 0 ..< settings.words {
        let index: Int = Int.random(in: 0 ..< wordlist.count, using: &rng)
        selectedWords.append(applyCase(wordlist[index], wordCase: settings.wordCase))
      }
      return selectedWords.joined(separator: settings.wordSeparator)
    }

    @Sendable
    func applyCase(_ word: String, wordCase: PasswordGeneratorCase) -> String {
      switch wordCase {
      case .lowercase:
        return word.lowercased()
      case .uppercase:
        return word.uppercased()
      case .camelcase:
        return word.capitalized
      }
    }

    @Sendable
    func passphraseEntropy(_ passphrase: String, _ settings: PassphraseGeneratorSettings) -> Entropy {
      let separator: String = settings.wordSeparator
      let wordCount: Int =
        separator.isEmpty
        ? 1
        : passphrase.components(separatedBy: separator).count
      guard wordCount > 0 else { return .zero }
      return .init(
        rawValue: Double(wordCount)
          * (log(Double(EFFWordlist.words.count * PasswordGeneratorCase.allCases.count)) / log(2))
      )
    }

    return .init(
      generate: generatePassphrase,
      entropy: passphraseEntropy
    )
  }
}

extension PassphraseGenerator {

  public struct GenerationError: TheError {

    public static func error(
      file: StaticString = #fileID,
      line: UInt = #line
    ) -> Self {
      Self(
        context: .context(
          .message(
            "Failed to generate passphrase",
            file: file,
            line: line
          )
        )
      )
    }

    public var context: DiagnosticsContext
  }

}

extension FeaturesRegistry {

  internal mutating func usePassphraseGenerator() {
    self.use(
      .disposable(
        PassphraseGenerator.self,
        load: PassphraseGenerator.load(using:)
      )
    )
  }
}
