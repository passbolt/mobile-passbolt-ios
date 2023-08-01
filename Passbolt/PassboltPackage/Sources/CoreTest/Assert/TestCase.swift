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

import XCTest

@dynamicMemberLookup
@MainActor open class TestCase: XCTestCase {

  private final nonisolated let lock: NSRecursiveLock = .init()
  private final nonisolated let dynamicVariables: DynamicVariables = .init()

  public nonisolated final subscript<Value>(
    dynamicMember keyPath: ReferenceWritableKeyPath<DynamicVariables, Value>
  ) -> Value {
    @Sendable _read {
      yield self.dynamicVariables[keyPath: keyPath]
    }
    @Sendable _modify {
      yield &self.dynamicVariables[keyPath: keyPath]
    }
  }

  @Sendable public nonisolated final func define<Value>(
    _ keyPath: KeyPath<DynamicVariables.Names, String>,
    of _: Value.Type = Value.self,
    initial: Value
  ) {
    self.dynamicVariables
      .define(
        keyPath,
        of: Value.self,
        initial: initial
      )
  }

  @Sendable public nonisolated final func withLock<Returned>(
    _ execute: () throws -> Returned
  ) rethrows -> Returned {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try execute()
  }
}

extension TestCase {

  @dynamicMemberLookup
  public final class DynamicVariables: @unchecked Sendable {

    @dynamicMemberLookup
    public struct Names: Sendable {

      fileprivate init() {}

      public subscript(
        dynamicMember name: StaticString
      ) -> String { name.description }
    }

    private let lock: NSLock
    private let names: Names
    private var storage: Dictionary<String, Any>

    fileprivate init() {
      self.lock = .init()
      self.names = .init()
      self.storage = .init()
    }

    public subscript<Value>(
      dynamicMember keyPath: KeyPath<Names, String>
    ) -> Value {
      @Sendable _read {
        self.lock.lock()
        let storageKey: String = self.names[keyPath: keyPath]
        guard let stored: Any = self.storage[storageKey]
        else { fatalError("Attempting to access undefined variable \(storageKey)!") }
        guard let value: Value = stored as? Value
        else {
          fatalError(
            "Attempting to access variable \(storageKey) of type \(Value.self) while storing \(type(of: stored))"
          )
        }
        yield value
        self.lock.unlock()
      }
      @Sendable _modify {
        self.lock.lock()
        let storageKey: String = self.names[keyPath: keyPath]
        guard let stored: Any = self.storage[storageKey]
        else { fatalError("Attempting to access undefined variable \(storageKey)!") }
        guard var value: Value = stored as? Value
        else {
          fatalError(
            "Attempting to access variable \(storageKey) of type \(Value.self) while storing \(type(of: stored))"
          )
        }
        yield &value
        self.storage[storageKey] = value
        self.lock.unlock()
      }
      @Sendable set {
        self.lock.lock()
        let storageKey: String = self.names[keyPath: keyPath]
        guard let stored: Any = self.storage[storageKey]
        else {
          self.define(keyPath, initial: newValue)
          return self.lock.unlock()
        }
        guard stored is Value
        else {
          fatalError(
            "Attempting to access variable \(storageKey) of type \(Value.self) while storing \(type(of: stored))"
          )
        }
        self.storage[storageKey] = newValue
        self.lock.unlock()
      }
    }

    @Sendable public nonisolated final func define<Value>(
      _ keyPath: KeyPath<Names, String>,
      of _: Value.Type = Value.self,
      initial: Value
    ) {
      self.lock.lock()
      let storageKey: String = self.names[keyPath: keyPath]
      guard case .none = self.storage[storageKey]
      else { fatalError("Attempting to redefine already defined variable \(storageKey)!") }
      self.storage[storageKey] = initial
      self.lock.unlock()
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verify(
    @_inheritActorContext @_implicitSelfCapture _ expression: @autoclosure () throws -> Bool?,
    _ message: @autoclosure () -> String = "",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) {
    do {
      let result: Bool = try expression() ?? true
      XCTAssert(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verify(
    @_implicitSelfCapture _ expression: @autoclosure @MainActor () async throws -> Bool?,
    _ message: @autoclosure () -> String = "",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async {
    do {
      let result: Bool = try await expression() ?? true
      XCTAssert(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIf<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
    isEqual expected: Expected,
    _ message: @autoclosure () -> String = "Values are not equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  )
  where Expected: Equatable {
    do {
      let result: Expected? = try expression()
      XCTAssertEqual(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIf<Expected>(
    _ expression: @autoclosure @MainActor () async throws -> Expected?,
    isEqual expected: Expected,
    _ message: @autoclosure () -> String = "Values are not equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Equatable {
    do {
      let result: Expected? = try await expression()
      XCTAssertEqual(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_transparent @Sendable public nonisolated final func verifyIf<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
    isNotEqual expected: Expected,
    _ message: @autoclosure () -> String = "Values are equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  )
  where Expected: Equatable {
    do {
      let result: Expected? = try expression()
      XCTAssertNotEqual(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIf<Expected>(
    _ expression: @autoclosure @MainActor () async throws -> Expected?,
    isNotEqual expected: Expected,
    _ message: @autoclosure () -> String = "Values are equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Equatable {
    do {
      let result: Expected? = try await expression()
      XCTAssertNotEqual(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIf<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected,
    isGreaterThan expected: Expected,
    _ message: @autoclosure () -> String = "Value is less than or equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  )
  where Expected: Comparable {
    do {
      let result: Expected = try expression()
      XCTAssertGreaterThan(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIf<Expected>(
    _ expression: @autoclosure @MainActor () async throws -> Expected,
    isGreaterThan expected: Expected,
    _ message: @autoclosure () -> String = "Value is less than or equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Comparable {
    do {
      let result: Expected = try await expression()
      XCTAssertGreaterThan(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_transparent @Sendable public nonisolated final func verifyIf<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected,
    isLessThan expected: Expected,
    _ message: @autoclosure () -> String = "Value is greater than or equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  )
  where Expected: Comparable {
    do {
      let result: Expected = try expression()
      XCTAssertLessThan(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIf<Expected>(
    _ expression: @autoclosure @MainActor () async throws -> Expected,
    isLessThan expected: Expected,
    _ message: @autoclosure () -> String = "Value is greater than or equal!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Comparable {
    do {
      let result: Expected = try await expression()
      XCTAssertLessThan(
        result,
        expected,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIf<Expected, Returned>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Returned,
    throws expected: Expected.Type,
    _ message: @autoclosure () -> String = "Error not thrown!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  )
  where Expected: Error {
    do {
      _ = try expression()
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
    catch is Expected {
      // expected
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIf<Expected, Returned>(
    _ expression: @autoclosure @MainActor () async throws -> Returned,
    throws expected: Expected.Type,
    _ message: @autoclosure () -> String = "Error not thrown!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Error {
    do {
      _ = try await expression()
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
    catch is Expected {
      // expected
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIfNotThrows<Returned>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Returned,
    _ message: @autoclosure () -> String = "Error thrown!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) {
    do {
      _ = try expression()
      // expected
    }
    catch {
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIfNotThrows<Returned>(
    _ expression: @autoclosure @MainActor () async throws -> Returned,
    _ message: @autoclosure () -> String = "Error thrown!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async {
    do {
      _ = try await expression()
      // expected
    }
    catch {
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIfIsNone<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
    _ message: @autoclosure () -> String = "Value is not none!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) {
    do {
      let result: Expected? = try expression()
      XCTAssertNil(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIfIsNone<Expected>(
    _ expression: @autoclosure @MainActor () async throws -> Expected?,
    _ message: @autoclosure () -> String = "Value is not none!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Equatable {
    do {
      let result: Expected? = try await expression()
      XCTAssertNil(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}

extension TestCase {

  @_transparent @Sendable public nonisolated final func verifyIfIsNotNone<Expected>(
    @_inheritActorContext _ expression: @autoclosure () throws -> Expected?,
    _ message: @autoclosure () -> String = "Value is none!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) {
    do {
      let result: Expected? = try expression()
      XCTAssertNotNil(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  @_disfavoredOverload
  @_transparent @MainActor public final func verifyIfIsNotNone<Expected>(
    equal expected: Expected,
    _ expression: @autoclosure @MainActor () async throws -> Expected?,
    _ message: @autoclosure () -> String = "Value is none!",
    _ file: StaticString = #filePath,
    _ line: UInt = #line
  ) async
  where Expected: Equatable {
    do {
      let result: Expected? = try await expression()
      XCTAssertNotNil(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}
