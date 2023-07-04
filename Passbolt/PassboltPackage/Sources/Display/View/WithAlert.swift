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

public struct AlertViewModel: Equatable {

  public enum Action: Equatable, Identifiable {

    public static func == (
      _ lhs: AlertViewModel.Action,
      _ rhs: AlertViewModel.Action
    ) -> Bool {
      switch (lhs, rhs) {
      case (.regular(let lID, let lTitle, _), .regular(let rID, let rTitle, _)):
        return lID == rID && lTitle == rTitle

      case (.destructive(let lID, let lTitle, _), .destructive(let rID, let rTitle, _)):
        return lID == rID && lTitle == rTitle

      case (.cancel(let lID, let lTitle), .cancel(let rID, let rTitle)):
        return lID == rID && lTitle == rTitle

      case _:
        return false
      }
    }

    public var id: IID {
      switch self {
      case .regular(let id, _, _):
        return id

      case .destructive(let id, _, _):
        return id

      case .cancel(let id, _):
        return id
      }
    }

    public var title: DisplayableString {
      switch self {
      case .regular(_, let title, _):
        return title

      case .destructive(_, let title, _):
        return title

      case .cancel(_, let title):
        return title
      }
    }

    public var role: ButtonRole? {
      switch self {
      case .regular:
        return .none

      case .destructive:
        return .destructive

      case .cancel:
        return .cancel
      }
    }

    public var perform: @MainActor () async -> Void {
      switch self {
      case .regular(_, _, let perform):
        return perform

      case .destructive(_, _, let perform):
        return perform

      case .cancel:
        return { /* NOP */  }
      }
    }

    case regular(
      id: IID = .init(),
      title: DisplayableString,
      perform: @MainActor () async -> Void
    )
    case destructive(
      id: IID = .init(),
      title: DisplayableString,
      perform: @MainActor () async -> Void
    )
    case cancel(
      id: IID = .init(),
      title: DisplayableString = "generic.cancel"
    )
  }

  public var title: DisplayableString
  public var message: DisplayableString
  public var actions: Array<Action>

  public init(
    title: DisplayableString,
    message: DisplayableString,
    actions: Array<Action>
  ) {
    self.title = title
    self.message = message
    self.actions = actions
  }
}

public struct WithAlert<AlertState, ContentView>: View
where AlertState: Equatable, ContentView: View {

  @ObservedObject private var viewState: TrimmedViewState<AlertState?>
  private let binding: Binding<AlertState?>
  private let alert: @Sendable (AlertState) -> AlertViewModel
  private let content: @MainActor () -> ContentView

  public init<Controller, ViewState>(
    from controller: Controller,
    at keyPath: WritableKeyPath<ViewState, AlertState?>,
    @ViewBuilder alert: @escaping @Sendable (AlertState) -> AlertViewModel,
    @ViewBuilder content: @escaping @MainActor () -> ContentView
  ) where Controller: ViewController, Controller.ViewState == ViewState {
    self._viewState = .init(
      wrappedValue: .init(
        from: controller.viewState,
        at: keyPath
      )
    )
    self.binding = controller.binding(to: keyPath)
    self.alert = alert
    self.content = content
  }

  public var body: some View {
    self.content()
      .alert(
        self.binding.wrappedValue.map(self.alert)?.title.string() ?? "",
        isPresented: self.binding.some(),
        presenting: self.binding.wrappedValue.map(self.alert),
        actions: { (alert: AlertViewModel) in
          ForEach(alert.actions) { (action: AlertViewModel.Action) in
            AsyncButton(
              role: action.role,
              action: action.perform,
              regularLabel: {
                Text(displayable: action.title)
              }
            )
          }
        },
        message: { (alert: AlertViewModel) in
          Text(displayable: alert.message)
        }
      )
  }
}
