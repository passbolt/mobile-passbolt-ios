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

public struct WithBindingState<State, ContentView>: View
where State: Equatable, ContentView: View {

  @ObservedObject private var viewState: TrimmedViewState<State>
  private let binding: Binding<State>
  private let content: (Binding<State>) -> ContentView

  public init<Controller>(
    from controller: Controller,
    @ViewBuilder content: @escaping (Binding<State>) -> ContentView
  ) where Controller: ViewController, Controller.ViewState == State {
    self._viewState = .init(
      wrappedValue: .init(from: controller.viewState)
    )
    self.binding = controller.binding(to: \.self)
    self.content = content
  }

  public init<Controller>(
    from controller: Controller,
    at keyPath: WritableKeyPath<Controller.ViewState, State>,
    @ViewBuilder content: @escaping (Binding<State>) -> ContentView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.binding(to: keyPath)
    self.content = content
  }

  public init<Controller>(
    from controller: Controller,
    at keyPath: WritableKeyPath<Controller.ViewState, State>,
    updating: @escaping @MainActor (State) -> Void,
    @ViewBuilder content: @escaping (Binding<State>) -> ContentView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.binding(
      to: keyPath,
      updating: updating
    )
    self.content = content
  }

  public init<Controller, ValidatedState>(
    from controller: Controller,
    atValidated keyPath: WritableKeyPath<Controller.ViewState, Validated<ValidatedState>>,
    updating: @escaping @MainActor (ValidatedState) -> Void,
    @ViewBuilder content: @escaping (Binding<Validated<ValidatedState>>) -> ContentView
  ) where Controller: ViewController, State == Validated<ValidatedState> {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.validatedBinding(
      to: keyPath,
      updating: updating
    )
    self.content = content
  }

  public var body: some View {
    self.content(self.binding)
  }
}
