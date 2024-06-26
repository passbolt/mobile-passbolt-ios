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

import Commons
import SwiftUI

public struct WithEachViewState<State, ContentView, PlaceholderView>: View
where
  State: RandomAccessCollection,
  State: Equatable,
  State.Element: Identifiable & Equatable,
  ContentView: View,
  PlaceholderView: View
{

  @ObservedObject private var viewState: TrimmedViewState<State>
  private let content: (State.Element) -> ContentView
  private let placeholder: () -> PlaceholderView

  public init<Controller>(
    from controller: Controller,
    at keyPath: KeyPath<Controller.ViewState, State>,
    @ViewBuilder content: @escaping (State.Element) -> ContentView,
    @ViewBuilder placeholder: @escaping () -> PlaceholderView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.content = content
    self.placeholder = placeholder
  }

  public init<Controller>(
    from controller: Controller,
    at keyPath: KeyPath<Controller.ViewState, State>,
    @ViewBuilder content: @escaping (State.Element) -> ContentView
  ) where Controller: ViewController, PlaceholderView == EmptyView {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.content = content
    self.placeholder = EmptyView.init
  }

  public init<Controller>(
    from controller: Controller,
    @ViewBuilder content: @escaping (State.Element) -> ContentView,
    @ViewBuilder placeholder: @escaping () -> PlaceholderView
  ) where Controller: ViewController, Controller.ViewState == State {
    self._viewState = .init(
      wrappedValue: .init(from: controller.viewState)
    )
    self.content = content
    self.placeholder = placeholder
  }

  public init<Controller>(
    from controller: Controller,
    @ViewBuilder content: @escaping (State.Element) -> ContentView
  ) where Controller: ViewController, Controller.ViewState == State, PlaceholderView == EmptyView {
    self._viewState = .init(
      wrappedValue: .init(from: controller.viewState)
    )
    self.content = content
    self.placeholder = EmptyView.init
  }

  public var body: some View {
    let viewState: State = self.viewState.value
    if viewState.isEmpty {
      self.placeholder()
    }
    else {
      ForEach(viewState) { element in
        self.content(element)
      }
    }
  }
}
