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
import XCTest

@testable import Commons

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AnyAsyncSequenceTests: XCTestCase {

  func test_iteration_returnsEmptySequence_withEmptyPublisher() async {
    let sequence: AnyAsyncSequence<Int> = .init(
      Empty<Int, Never>(completeImmediately: true)
    )

    var result: Array<Int> = .init()
    for await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [])
  }

  func test_iteration_returnsSequenceContent_withNonemptyPublisher() async {
    let sequence: AnyAsyncSequence<Int> = .init(
      [1, 2, 3]
        .publisher
    )

    var result: Array<Int> = .init()
    for await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [1, 2, 3])
  }

  func test_iteration_returnsSequenceContent_withEmptySequence() async {
    let content: AsyncStream<Int> = .init { continuation in
      continuation.finish()
    }

    let sequence: AnyAsyncSequence<Int> = .init(content)

    var result: Array<Int> = .init()
    for await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [])
  }

  func test_iteration_returnsSequenceContent_withNonemptySequence() async {
    let content: AsyncStream<Int> = .init { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.yield(3)
      continuation.finish()
    }

    let sequence: AnyAsyncSequence<Int> = .init(content)

    var result: Array<Int> = .init()
    for await element in sequence {
      result.append(element)
    }

    XCTAssertEqual(result, [1, 2, 3])
  }
}
