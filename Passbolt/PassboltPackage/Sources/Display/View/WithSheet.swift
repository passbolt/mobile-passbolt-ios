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

public struct WithSheet<State, SheetView, ContentView>: View
where State: Equatable & Identifiable, SheetView: View, ContentView: View {

  @ObservedObject private var viewState: TrimmedViewState<State?>
  private let binding: Binding<State?>
  private let sheet: @MainActor (State) -> SheetView
  private let content: @MainActor () -> ContentView

  public init<Controller>(
    from controller: Controller,
    at keyPath: WritableKeyPath<Controller.ViewState, State?>,
    @ViewBuilder sheet: @escaping (State) -> SheetView,
    @ViewBuilder content: @escaping () -> ContentView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.binding(to: keyPath)
    self.sheet = sheet
    self.content = content
  }

  public var body: some View {
    self.content()
      .sheet(
        item: self.binding,
        content: { (state: State) in
          self.sheet(state)
        }
      )
  }
}

public struct WithToggledSheet<SheetView, ContentView>: View
where SheetView: View, ContentView: View {

  @ObservedObject private var viewState: TrimmedViewState<Bool>
  private let binding: Binding<Bool>
  private let sheet: @MainActor () -> SheetView
  private let content: @MainActor () -> ContentView

  public init<Controller>(
    from controller: Controller,
    at keyPath: WritableKeyPath<Controller.ViewState, Bool>,
    @ViewBuilder sheet: @escaping () -> SheetView,
    @ViewBuilder content: @escaping () -> ContentView
  ) where Controller: ViewController {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.binding(to: keyPath)
    self.sheet = sheet
    self.content = content
  }

  public var body: some View {
    self.content()
      .sheet(
        isPresented: self.binding,
        content: {
          self.sheet()
        }
      )
  }
}
