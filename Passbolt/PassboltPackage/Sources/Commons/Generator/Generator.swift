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

public struct Generator<Value> {

  public let next: () -> Value

  fileprivate init(
    next: @escaping () -> Value
  ) {
    self.next = next
  }
}

public typealias RandomnessUnit = Tagged<UInt64, RandomNumberGenerator>

public typealias RandomnessGenerator = Generator<RandomnessUnit>

extension RandomnessGenerator {

  internal var asRNG: RNG {
    RNG(from: self)
  }

  internal func withRNG<Return>(
    _ execute: (inout RNG) -> Return
  ) -> Return {
    var rng: RNG = .init(from: self)
    return execute(&rng)
  }

  internal func fixed() -> Self {
    let fixedResult: RandomnessUnit = self.next()
    return .init { fixedResult }
  }

  public static func source(
    from nextRandom: @escaping () -> RandomnessUnit
  ) -> Self {
    .init(next: nextRandom)
  }

  #if DEBUG
  public static let sharedDebugRandomSource: RandomnessGenerator = debugRandomSource(seed: 0)

  public static func debugRandomSource(
    seed: RandomnessUnit
  ) -> Self {
    let state: CriticalState<RandomnessUnit> = .init(seed)

    return .init(
      next: {
        state.access { seed in
          seed.rawValue = 2_862_933_555_777_941_757 &* seed.rawValue &+ 3_037_000_493
          return seed
        }
      }
    )
  }
  #endif
}

extension Generator where Value: RandomlyGenerated {

  public static func random(
    using randomnessGenerator: RandomnessGenerator
  ) -> Value {
    Value.randomGenerator(using: randomnessGenerator).next()
  }

  #if DEBUG

  public static func random() -> Value {
    random(using: .sharedDebugRandomSource)
  }
  #endif
}

#if DEBUG

extension RandomlyGenerated {

  public static func random() -> Self {
    Self.random(using: .sharedDebugRandomSource)
  }
}
#endif

extension Generator {

  public static func always(
    _ value: @escaping @autoclosure () -> Value
  ) -> Self {
    .init(next: value)
  }

  public func withDefault<WrappedValue>(
    _ defaulValue: @escaping @autoclosure () -> WrappedValue
  ) -> Generator<WrappedValue>
  where Value == Optional<WrappedValue> {
    .always(
      self.next() ?? defaulValue()
    )
  }

  public func array(
    withCount count: @escaping @autoclosure () -> Int
  ) -> Generator<Array<Value>> {
    .init {
      let count: Int = count()
      assert(count >= 0, "Cannot use negative count")

      var array: Array<Value> = .init()
      array.reserveCapacity(count)

      for _ in 0..<count {
        array.append(self.next())
      }

      return array
    }
  }

  public func array(
    withCountIn range: @escaping @autoclosure () -> Range<Int>,
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Array<Value>> {
    self.array(
      withCount: range()
        .randomElementGenerator(using: randomnessGenerator)
        .next() ?? 0
    )
  }

  public func map<NewValue>(
    _ mapping: @escaping (Value) -> NewValue
  ) -> Generator<NewValue> {
    .init(
      next: {
        mapping(self.next())
      }
    )
  }

  public func flatMap<NewValue>(
    _ mapping: @escaping (Value) -> Generator<NewValue>
  ) -> Generator<NewValue> {
    .init(
      next: {
        mapping(self.next()).next()
      }
    )
  }
}

extension Generator {

  public func appending<Element>(
    _ element: Element
  ) -> Self
  where Value == Array<Element> {
    .init {
      var next: Value = self.next()
      next.append(element)
      return next
    }
  }

  public func inserting<Element>(
    _ element: Element
  ) -> Self
  where Value == Set<Element> {
    .init {
      var next: Value = self.next()
      next.insert(element)
      return next
    }
  }
}

public func zip<A1, A2, R>(
  with mapping: @escaping (A1, A2) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next()
      )
    }
  )
}

public func zip<A1, A2, A3, R>(
  with mapping: @escaping (A1, A2, A3) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, R>(
  with mapping: @escaping (A1, A2, A3, A4) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, A8, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7, A8) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>,
  _ g8: Generator<A8>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next(),
        g8.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>,
  _ g8: Generator<A8>,
  _ g9: Generator<A9>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next(),
        g8.next(),
        g9.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>,
  _ g8: Generator<A8>,
  _ g9: Generator<A9>,
  _ g10: Generator<A10>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next(),
        g8.next(),
        g9.next(),
        g10.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>,
  _ g8: Generator<A8>,
  _ g9: Generator<A9>,
  _ g10: Generator<A10>,
  _ g11: Generator<A11>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next(),
        g8.next(),
        g9.next(),
        g10.next(),
        g11.next()
      )
    }
  )
}

public func zip<A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, R>(
  with mapping: @escaping (A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12) -> R,
  _ g1: Generator<A1>,
  _ g2: Generator<A2>,
  _ g3: Generator<A3>,
  _ g4: Generator<A4>,
  _ g5: Generator<A5>,
  _ g6: Generator<A6>,
  _ g7: Generator<A7>,
  _ g8: Generator<A8>,
  _ g9: Generator<A9>,
  _ g10: Generator<A10>,
  _ g11: Generator<A11>,
  _ g12: Generator<A12>
) -> Generator<R> {
  .init(
    next: {
      mapping(
        g1.next(),
        g2.next(),
        g3.next(),
        g4.next(),
        g5.next(),
        g6.next(),
        g7.next(),
        g8.next(),
        g9.next(),
        g10.next(),
        g11.next(),
        g12.next()
      )
    }
  )
}

internal struct RNG: RandomNumberGenerator {

  private let nextRandom: () -> RandomnessUnit

  fileprivate init(
    from randomnessGenerator: RandomnessGenerator
  ) {
    self.nextRandom = randomnessGenerator.next
  }

  internal func next() -> UInt64 {
    self.nextRandom().rawValue
  }
}
