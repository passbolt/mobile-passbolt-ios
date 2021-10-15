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
import func Darwin.log

public struct RandomStringGenerator {

  public var generate: (
    _ alphabet: Set<Character>,
    _ targetEntropy: Entropy
  ) -> String

  public var entropy: (
    _ password: String,
    _ alphabetCount: Int
  ) -> Entropy
}

extension RandomStringGenerator: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> RandomStringGenerator {

    var randomness: Randomness = environment.randomness

    func entropy(
      password: String,
      alphabetCount: Int
    ) -> Entropy {
      if !password.isEmpty && alphabetCount > 0 {
        return .init(rawValue: Double(password.count) * (log(Double(alphabetCount)) / log(2)))
      }
      else {
        return .zero
      }
    }

    func generate(
      from alphabet: Set<Character>,
      with targetEntropy: Entropy
    ) -> String {

      assert(!alphabet.isEmpty && targetEntropy.rawValue > 0)

      var output: String = ""

      while entropy(
        password: output,
        alphabetCount: alphabet.count
      ) < targetEntropy {
        guard let element = alphabet.randomElement(using: &randomness)
        else { continue }

        output.append(element)
      }

      return output
    }

    return Self(
      generate: generate(from:with:),
      entropy: entropy(password:alphabetCount:)
    )
  }
}

#if DEBUG
extension RandomStringGenerator {

  public static var placeholder: RandomStringGenerator {
    Self(
      generate: Commons.placeholder("You have to provide mocks for used methods"),
      entropy: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
