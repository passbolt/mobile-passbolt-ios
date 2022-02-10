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

import func Darwin.log

public struct RandomStringGenerator {

  public var generate:
    (
      _ alphabets: Set<Set<Character>>,  // sets have to be disjoint
      _ minLength: Int,
      _ targetEntropy: Entropy
    ) -> String

  public var entropy:
    (
      _ password: String,
      _ alphabets: Set<Set<Character>>  // sets have to be disjoint
    ) -> Entropy
}

extension RandomStringGenerator: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> RandomStringGenerator {

    var randomness: Randomness = environment.randomness

    func entropy(
      password: String,
      alphabets: Set<Set<Character>>
    ) -> Entropy {

      guard !password.isEmpty && !alphabets.isEmpty && alphabets.contains(where: { !$0.isEmpty })
      else { return .zero }

      let usedAlphabet: Set<Character> = Set(password).reduce(into: .init()) { result, character in
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

    func generate(
      from alphabets: Set<Set<Character>>,
      minLength: Int,
      with targetEntropy: Entropy
    ) -> String {

      assert(!alphabets.isEmpty && minLength > 0 && targetEntropy.rawValue > 0)

      var output: String = ""
      let entireAlphabet: Set<Character> = alphabets.reduce(.init()) { $0.union($1) }

      while entropy(
        password: output,
        alphabets: alphabets
      ) < targetEntropy || output.count < minLength {
        guard let element = entireAlphabet.randomElement(using: &randomness)
        else { continue }

        output.append(element)
      }

      return output
    }

    return Self(
      generate: generate(from:minLength:with:),
      entropy: entropy(password:alphabets:)
    )
  }
}


extension RandomStringGenerator {

  public var featureUnload: () -> Bool { { true } }
}

#if DEBUG
extension RandomStringGenerator {

  public static var placeholder: RandomStringGenerator {
    Self(
      generate: unimplemented("You have to provide mocks for used methods"),
      entropy: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
