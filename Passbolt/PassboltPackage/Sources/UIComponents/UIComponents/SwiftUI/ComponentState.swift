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

@MainActor @dynamicMemberLookup
public final class ComponentObservableState<State>: ObservableObject
where State: Hashable {

  @Published public fileprivate(set) var value: State

  fileprivate init(
    initial: State
  ) {
    self.value = initial
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.value[keyPath: keyPath] }
    set { self.value[keyPath: keyPath] = newValue }
  }
}

@MainActor @dynamicMemberLookup
public final class ComponentWritableState<State>
where State: Hashable {

  private let observableState: ComponentObservableState<State>

  public init(
    initial: State
  ) {
    self.observableState = .init(initial: initial)
  }

  public subscript<Value>(
    dynamicMember keyPath: WritableKeyPath<State, Value>
  ) -> Value {
    get { self.observableState.value[keyPath: keyPath] }
    set { self.observableState.value[keyPath: keyPath] = newValue }
  }
}

extension ComponentWritableState {

  public var value: State {
    get { self.observableState.value }
    set {
      guard self.observableState.value != newValue else { return }
      self.observableState.value = newValue
    }
  }

  public func asObservableState() -> ComponentObservableState<State> {
    self.observableState
  }
}
