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

//// warn - unfair values distribution, there is no guarantee that each
//// awaiter will get all values
//public struct AsyncThrowingPassthroughSequence<Element> {
//
//  private let sharedIterator: AsyncThrowingSharedIterator<Element> = .init()
//
//  public init() {}
//}
//
//extension AsyncThrowingPassthroughSequence: AsyncSequence {
//
//  public func makeAsyncIterator() -> AsyncThrowingSharedIterator<Element> {
//    self.sharedIterator
//  }
//}
//
//extension AsyncThrowingPassthroughSequence {
//
//  public func yield(_ element: Element) async throws {
//    await self.sharedIterator.yield(element)
//  }
//
//  public func finish() async {
//    await self.sharedIterator.finish()
//  }
//}
