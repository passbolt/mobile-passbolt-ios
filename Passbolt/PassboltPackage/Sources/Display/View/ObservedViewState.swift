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

internal final class ObservedViewState<ViewState>: ObservableObject
where ViewState: Sendable & Equatable {

  internal let objectWillChange: ObservableObjectPublisher
  @MainActor internal var state: ViewState {
    willSet {
      // remove duplicates
      guard newValue != state else { return }
      self.objectWillChange.send()
    }
  }
  private let updates: Updates
  private let readState: () async -> ViewState
  private let requestUpdateIfNeeded: () async -> Void

  @MainActor internal init<Source>(
    from source: Source
  ) where Source: DataSource, Source.Failure == Never, ViewState == Optional<Source.DataType> {
    self.state = .none
    self.readState = {
      // can't throw here, Failure should be Never
      try? await source.value
    }
    self.requestUpdateIfNeeded = {}
    self.updates = source.updates
    self.objectWillChange = .init()
  }

  @MainActor internal init<Source>(
    from source: Source
  ) where Source: ViewStateSource, Source.ViewState == ViewState {
    self.state = source.state
    self.readState = { source.state }
    if let computedSource = source as? ComputedViewState<Source.ViewState> {
      self.requestUpdateIfNeeded = computedSource.updateIfNeeded
    }
    else if let updatableSource = source as? UpdatableViewState<Source.ViewState> {
      self.requestUpdateIfNeeded = updatableSource.updateIfNeeded
    }
    else {
      self.requestUpdateIfNeeded = {}
    }
    self.updates = source.updates
    self.objectWillChange = .init()
  }

  @MainActor internal init<Source>(
    from source: Source,
    at keyPath: KeyPath<Source.ViewState, ViewState>
  ) where Source: ViewStateSource, Source.ViewState: Equatable {
    self.state = source.state[keyPath: keyPath]
    self.readState = { source.state[keyPath: keyPath] }
    if let computedSource = source as? ComputedViewState<Source.ViewState> {
      self.requestUpdateIfNeeded = computedSource.updateIfNeeded
    }
    else if let updatableSource = source as? UpdatableViewState<Source.ViewState> {
      self.requestUpdateIfNeeded = updatableSource.updateIfNeeded
    }
    else {
      self.requestUpdateIfNeeded = {}
    }
    self.updates = source.updates
    self.objectWillChange = .init()
  }
}

extension ObservedViewState {

  @MainActor internal func autoupdate() async {
    for await _ in self.updates {
      await self.requestUpdateIfNeeded()
      self.state = await self.readState()
    }
  }
}
