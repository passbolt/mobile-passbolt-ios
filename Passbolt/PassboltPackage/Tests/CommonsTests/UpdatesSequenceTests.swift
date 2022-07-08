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
final class UpdatesSequenceTests: AsyncTestCase {

  func test_checkUpdate_throws_withoutUpdate() {
    asyncTestThrows(NoUpdate.self) { () -> UpdatesSequence.Generation in
      let updatesSequence: UpdatesSequence = .init()

      return try await updatesSequence.checkUpdate(after: 1)
    }
  }

  func test_checkUpdate_returns_withUpdate() {
    asyncTestNotThrows { () -> UpdatesSequence.Generation in
      let updatesSequence: UpdatesSequence = .init()

      return try await updatesSequence.checkUpdate(after: 0)
    }
  }

  func test_update_generatesNextValue() {
    asyncTestReturnsSome { () -> Void? in
      let updatesSequence: UpdatesSequence = .init()

      var iterator: UpdatesSequence.AsyncIterator = updatesSequence.makeAsyncIterator()
      _ = await iterator.next()  // drop first
      updatesSequence.sendUpdate()
      return await iterator.next()
    }
  }

  func test_deinit_endsSequence() {
    asyncTestReturnsNone { () -> Void? in
      let uncheckedSendableSequence: UncheckedSendable<UpdatesSequence?> = .init(.init())

      var iterator: UpdatesSequence.AsyncIterator = uncheckedSendableSequence.variable!.makeAsyncIterator()

      uncheckedSendableSequence.variable = .none

      return await iterator.next()
    }
  }
}
