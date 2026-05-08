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

import CommonModels
import Features
import OSFeatures

import func Darwin.log

internal struct PasswordGenerator: Sendable {

  internal typealias Alphabet = Set<Character>

  fileprivate static let maximumAttempts: Int = 10
  fileprivate static let minimumEntropy: Entropy = .strongPassword

  internal var generate: @Sendable (PasswordGeneratorSettings) throws -> String
  internal var entropy: @Sendable (_ password: String, _ settings: PasswordGeneratorSettings) -> Entropy
}

extension PasswordGenerator: LoadableFeature {

  @MainActor internal static func load(
    using features: Features
  ) -> PasswordGenerator {
    let randomness: OSRandomness = features.instance()

    @Sendable func entropy(
      password: String,
      settings: PasswordGeneratorSettings
    ) -> Entropy {
      let alphabets: Set<Alphabet> = settings.characterSets
      guard !password.isEmpty && !alphabets.isEmpty && alphabets.contains(where: { !$0.isEmpty })
      else { return .zero }

      let usedAlphabet: Set<Character> = Set(password)
        .reduce(into: .init()) { result, character in
          for alphabet in alphabets {
            if alphabet.contains(character) {
              return result.formUnion(alphabet)
            }
            else {
              /* NOP */
            }
          }

          result.insert(character)
        }

      return .init(rawValue: Double(password.count) * (log(Double(usedAlphabet.count)) / log(2)))
    }

    @Sendable func generate(settings: PasswordGeneratorSettings) throws -> String {
      let alphabets: Set<Alphabet> = settings.characterSets
      let entireAlphabet: Set<Character> = alphabets.reduce(.init()) { $0.union($1) }
      guard !entireAlphabet.isEmpty else { throw GenerationError.error() }

      var rng: OSRandomness = randomness
      var attempt: Int = 0
      // Random chars might not be enough to meet the entropy requirement,
      // so we need to loop until we get a valid password or reach the maximum number of attempts
      while attempt < Self.maximumAttempts {
        var output: String = ""
        var calculatedEntropy: Entropy = .zero
        while calculatedEntropy < Self.minimumEntropy || output.count < settings.length {
          guard let element = entireAlphabet.randomElement(using: &rng)
          else { continue }
          output.append(element)
          calculatedEntropy = entropy(password: output, settings: settings)
        }
        if calculatedEntropy >= Self.minimumEntropy && output.count >= settings.length {
          return output
        }
        attempt += 1
      }

      throw GenerationError.error()
    }

    return Self(
      generate: generate(settings:),
      entropy: entropy(password:settings:)
    )
  }
}

extension PasswordGenerator {

  internal struct GenerationError: TheError {

    public static func error(
      file: StaticString = #fileID,
      line: UInt = #line
    ) -> Self {
      Self(
        context: .context(
          .message(
            "Failed to generate password",
            file: file,
            line: line
          )
        )
      )
    }

    public var context: DiagnosticsContext
  }
}

#if DEBUG
extension PasswordGenerator {

  nonisolated internal static var placeholder: PasswordGenerator {
    Self(
      generate: unimplemented1(),
      entropy: unimplemented2()
    )
  }
}
#endif

extension FeaturesRegistry {

  internal mutating func usePasswordGenerator() {
    self.use(
      .disposable(
        PasswordGenerator.self,
        load: PasswordGenerator.load(using:)
      )
    )
  }
}

extension PasswordGeneratorSettings {

  fileprivate var characterSets: Set<Set<Character>> {
    var sets: Array<CharacterSets> = .init()

    if self.maskUpper {
      sets.append(.uppercaseLetters)
    }
    if self.maskLower {
      sets.append(.lowercaseLetters)
    }
    if self.maskDigit {
      sets.append(.digits)
    }
    if self.maskChar1 {
      sets.append(.specialChar1)
    }
    if self.maskChar2 {
      sets.append(.specialChar2)
    }
    if self.maskChar3 {
      sets.append(.specialChar3)
    }
    if self.maskChar4 {
      sets.append(.specialChar4)
    }
    if self.maskChar5 {
      sets.append(.specialChar5)
    }
    if self.maskParenthesis {
      sets.append(.parenthesis)
    }
    if self.maskEmoji {
      sets.append(.emoji)
    }

    let excludedCharacters: Set<Character>? =
      self.excludeLookAlikeChars
      ? CharacterSets.alikeCharacters.characters
      : .none

    return .init(
      sets.map { $0.characters.excluding(excludedCharacters) }
    )
  }
}

extension Set where Element == Character {

  fileprivate func excluding(_ characters: Set<Character>?) -> Set<Character> {
    guard let characters = characters else {
      return self
    }
    return self.subtracting(characters)
  }
}
