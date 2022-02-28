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

public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {

  @usableFromInline internal let nextElement: () async -> Element?

  internal init(
    nextElement: @escaping () async -> Element?
  ) {
    self.nextElement = nextElement
  }

  @inlinable public func next() async -> Element? {
    await nextElement()
  }
}

extension AsyncIteratorProtocol {

  internal func asAnyAsyncIterator() -> AnyAsyncIterator<Element> {
    // protocol requirement marks `next` as mutating
    // it forces to create mutable copy of self
    var mutableCopy: Self = self
    return .init(
      nextElement: {
        do {
          return try await mutableCopy.next()
        }
        catch {
          // we can't get the details if Content sequence is throwing or not
          // so if it is it will be treated as sequence end since we can't rethrow
          error
            .asTheError()
            .asAssertionFailure(
              message: "AnyAsyncIterator should not use throwing iterators, please use AnyAsyncThrowingIterator instead"
            )
          return nil
        }
      }
    )
  }
}
