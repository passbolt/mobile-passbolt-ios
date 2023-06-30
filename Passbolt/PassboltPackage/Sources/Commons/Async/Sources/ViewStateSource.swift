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

import SwiftUI

public protocol ViewStateSource<ViewState>: DataSource
where
  DataType == ViewState,
  Failure == Never,
  Element == DataType,
  AsyncIterator == AsyncThrowingMapSequence<Updates, DataType>.Iterator
{

  associatedtype ViewState: Sendable

  nonisolated var updates: Updates { @Sendable get }

  var state: ViewState { @MainActor get }
}

extension ViewStateSource /* DataSource */ {

  // there is a warning in Swift 5.8 but it does not compile without it
  // regardless of type constraint in protocol declaration
  public typealias DataType = ViewState
  public typealias Failure = Never

  public var value: DataType { @Sendable get async { self.state } }
}

#if DEBUG

public final class PlaceholderViewStateSource<ViewState>: ViewStateSource
where ViewState: Sendable {
  // It seems that there is some bug in swift 5.8 compiler,
  // typealiases below are already defined but it does not compile without it
  public typealias DataType = ViewState
  public typealias Failure = Never
  public typealias Element = ViewState
  public typealias AsyncIterator = AsyncThrowingMapSequence<Updates, ViewState>.Iterator

  public let updates: Updates = .placeholder

  public init() {}

  @MainActor public var state: ViewState {
    @inlinable get { unimplemented() }
  }
}

#endif
