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

import Combine
import TestExtensions
import XCTest

@testable import Commons

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AnyAsyncThrowingSequenceTests: XCTestCase {

  func test_iteration_returnsEmptySequence_withEmptyPublisher() async throws {
    let sequence: AnyAsyncThrowingSequence<Int> = .init(
      Empty<Int, Error>(completeImmediately: true)
    )

    var result: Array<Int> = .init()
    for try await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [])
  }

  func test_iteration_throws_withError() async {
    let sequence: AnyAsyncThrowingSequence<Int> = .init(
      Fail<Int, Error>(error: CancellationError())
    )

    do {
      for try await _ in sequence {}
      XCTFail("Expected to throw an error")
    }
    catch {
      // expected result
    }
  }

  func test_iteration_returnsSequenceContent_withNonemptyPublisher() async throws {
    let sequence: AnyAsyncThrowingSequence<Int> = .init(
      [1, 2, 3]
        .publisher
    )

    var result: Array<Int> = .init()
    for try await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [1, 2, 3])
  }

  func test_iteration_returnsSequencePartialContent_withNonemptyPublisherWithError() async {
    let subject: PassthroughSubject<Int, Error> = .init()

    let sequence: AnyAsyncThrowingSequence<Int> = .init(subject)

    Task.detached {
      subject.send(completion: .failure(CancellationError()))
    }

    var result: Array<Int> = .init()
    do {
      for try await element in sequence {
        result.append(element)
      }
      XCTFail("Expected to throw an error")
    }
    catch {
      // expected result
    }

    XCTAssertEqual(result, [])
  }

  func test_iteration_returnsSequenceContent_withEmptySequence() async throws {
    let content: AsyncThrowingStream<Int, Error> = .init { continuation in
      continuation.finish()
    }

    let sequence: AnyAsyncThrowingSequence<Int> = .init(content)

    var result: Array<Int> = .init()
    for try await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [])
  }

  func test_iteration_returnsSequenceContent_withNonemptySequence() async throws {
    let content: AsyncThrowingStream<Int, Error> = .init { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.yield(3)
      continuation.finish()
    }
    let sequence: AnyAsyncThrowingSequence<Int> = .init(content)

    var result: Array<Int> = .init()
    for try await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [1, 2, 3])
  }

  func test_iteration_returnsSequencePartialContent_withNonemptySequenceWithError() async throws {
    let content: AsyncThrowingStream<Int, Error> = .init { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.finish(throwing: MockIssue.error())
    }

    let sequence: AnyAsyncThrowingSequence<Int> = .init(content)

    var result: Array<Int> = .init()
    do {
      for try await element in sequence {
        result.append(element)
      }
      XCTFail("Expected to throw an error")
    }
    catch {
      // expected result
    }

    XCTAssertEqual(result, [1, 2])
  }
}
