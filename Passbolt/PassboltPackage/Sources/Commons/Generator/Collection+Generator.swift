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

extension Collection {

  public func randomElementGenerator(
    using randomnessGenerator: Commons.RandomnessGenerator
  ) -> Commons.Generator<Element?> {
    .always(
      randomnessGenerator.withRNG(self.randomElement(using:))
    )
  }

  public func randomNonEmptyElementGenerator(
    using randomnessGenerator: Commons.RandomnessGenerator
  ) -> Commons.Generator<Element> {
    Commons.Generator<Element?>.always(
      randomnessGenerator.withRNG(self.randomElement(using:))
    )
    .withDefault(unreachable("Array is not empty")())
  }
}

extension Generator {

  public static func any(
    of head: Generator<Value>,
    _ tail: Generator<Value>...,
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Value> {
    ([head] + tail)
      .randomNonEmptyElementGenerator(using: randomnessGenerator)
      .flatMap { $0 }
  }
}

extension Array where Element: RandomlyGenerated {

  public static func random(
    count: Int,
    using randomnessGenerator: RandomnessGenerator
  ) -> Self {
    Self.Element
      .randomGenerator(using: randomnessGenerator)
      .array(withCount: count)
      .next()
  }

  public static func random(
    countIn range: Range<Int>,
    using randomnessGenerator: RandomnessGenerator
  ) -> Self {
    Self.Element
      .randomGenerator(using: randomnessGenerator)
      .array(withCountIn: range, using: randomnessGenerator)
      .next()
  }
}

#if DEBUG
extension Array where Element: RandomlyGenerated {

  public static func random(count: Int) -> Self {
    Self.Element
      .randomGenerator(using: .sharedDebugRandomSource)
      .array(withCount: count)
      .next()
  }

  public static func random(
    countIn range: Range<Int>
  ) -> Self {
    Self.Element
      .randomGenerator(using: .sharedDebugRandomSource)
      .array(withCountIn: range, using: .sharedDebugRandomSource)
      .next()
  }
}
#endif
