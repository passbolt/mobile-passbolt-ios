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

public struct WithEachViewState<State, ContentView, PlaceholderView>: View
where
  State: RandomAccessCollection,
  State: Equatable,
  State.Element: Identifiable & Equatable,
  ContentView: View,
  PlaceholderView: View
{

  @StateObject private var viewState: ObservedViewState<State>
  private let content: (State.Element) -> ContentView
  private let placeholder: () -> PlaceholderView

  public init<Source>(
    _ source: Source,
    @ViewBuilder content: @escaping (State.Element) -> ContentView,
    @ViewBuilder placeholder: @escaping () -> PlaceholderView
  ) where Source: ViewStateSource, Source.ViewState == State {
    self._viewState = .init(
      wrappedValue: ObservedViewState(from: source)
    )
    self.content = content
    self.placeholder = placeholder
  }

  public init<Source>(
    _ source: Source,
    @ViewBuilder content: @escaping (State.Element) -> ContentView
  ) where Source: ViewStateSource, Source.ViewState == State, PlaceholderView == Display.PlaceholderView {
    self._viewState = .init(
      wrappedValue: ObservedViewState(from: source)
    )
    self.content = content
    self.placeholder = PlaceholderView.init
  }

  public init<Controller>(
    from controller: Controller,
    at keyPath: KeyPath<Controller.ViewState, State>,
    @ViewBuilder content: @escaping (State.Element) -> ContentView,
    @ViewBuilder placeholder: @escaping () -> PlaceholderView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: ObservedViewState(
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
  ) where Controller: ViewController, PlaceholderView == Display.PlaceholderView {
    self._viewState = .init(
      wrappedValue: ObservedViewState(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.content = content
    self.placeholder = PlaceholderView.init
  }

  public init<Controller>(
    from controller: Controller,
    @ViewBuilder content: @escaping (State.Element) -> ContentView,
    @ViewBuilder placeholder: @escaping () -> PlaceholderView
  ) where Controller: ViewController, Controller.ViewState == State {
    self._viewState = .init(
      wrappedValue: ObservedViewState(from: controller.viewState)
    )
    self.content = content
    self.placeholder = placeholder
  }

  public init<Controller>(
    from controller: Controller,
    @ViewBuilder content: @escaping (State.Element) -> ContentView
  ) where Controller: ViewController, Controller.ViewState == State, PlaceholderView == Display.PlaceholderView {
    self._viewState = .init(
      wrappedValue: ObservedViewState(from: controller.viewState)
    )
    self.content = content
    self.placeholder = PlaceholderView.init
  }

  public var body: some View {
    Group {
      if self.viewState.state.isEmpty {
        // placeholder can't be EmptyView, it will break `task` otherwise
        self.placeholder()
      }
      else {
        ForEach(self.viewState.state) { element in
          self.content(element)
        }
      }
    }
    .task { await self.viewState.autoupdate() }
  }
}
