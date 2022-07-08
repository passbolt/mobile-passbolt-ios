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

import TestExtensions
import XCTest

@testable import Commons

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UpdatableValueTests: AsyncTestCase {

  var updatesSequence: UpdatesSequence!

  override func setUp() async throws {
    try await super.setUp()
    self.updatesSequence = .init()
  }

  override func tearDown() async throws {
    self.updatesSequence = .none
    try await super.tearDown()
  }

  func test_value_returnsUpdatedValue_initially() {
    asyncTestReturnsEqual(0) {
      var nextValueState: Int = 0
      let nextValue: () -> Int = {
        defer { nextValueState += 1 }
        return nextValueState
      }
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          nextValue()
        }
      )

      return try await updatableValue.value
    }
  }

  func test_value_requestsUpdate_initially() {
    asyncTestExecuted { executed in
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          executed()
          return 42
        }
      )

      _ = try await updatableValue.value
    }
  }

  func test_value_returnsUpdatedValue_whenUpdatesSequenceEmitsAfterInitialUpdate() {
    asyncTestReturnsEqual(1) {
      var nextValueState: Int = 0
      let nextValue: () -> Int = {
        defer { nextValueState += 1 }
        return nextValueState
      }
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          nextValue()
        }
      )

      _ = try await updatableValue.value
      self.updatesSequence.sendUpdate()
      return try await updatableValue.value
    }
  }

  func test_value_returnsUpdatedValue_whenUpdatesSequenceEmitsBeforeInitialUpdate() {
    asyncTestReturnsEqual(0) {
      var nextValueState: Int = 0
      let nextValue: () -> Int = {
        defer { nextValueState += 1 }
        return nextValueState
      }
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          nextValue()
        }
      )

      self.updatesSequence.sendUpdate()
      return try await updatableValue.value
    }
  }

  func test_value_doesNotRequestUpdate_whenUpdatesSequenceNotEmitAfterInitialUpdate() {
    asyncTestExecuted(count: 1) { executed in
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          executed()
          return 42
        }
      )
      _ = try await updatableValue.value
      _ = try await updatableValue.value
    }
  }

  func test_value_requestsUpdate_whenUpdatesSequenceEmitsAfterInitialUpdate() {
    asyncTestExecuted(count: 2) { executed in
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          executed()
          return 42
        }
      )
      _ = try await updatableValue.value
      self.updatesSequence.sendUpdate()
      _ = try await updatableValue.value
    }
  }

  func test_value_requestsUpdateOnce_whenUpdatesSequenceEmitsBeforeInitialUpdate() {
    asyncTestExecuted(count: 1) { executed in
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          executed()
          return 42
        }
      )

      self.updatesSequence.sendUpdate()
      _ = try await updatableValue.value
    }
  }

  func test_value_doesNotRequestUpdates_whenUpdatesSequenceDeinits() {
    asyncTestExecuted(count: 0) { executed in
      let updatableValue: UpdatableValue<Int> = .init(
        updatesSequence: self.updatesSequence,
        update: {
          executed()
          return 42
        }
      )

      self.updatesSequence = .none

      _ = try? await updatableValue.value
    }
  }
}
