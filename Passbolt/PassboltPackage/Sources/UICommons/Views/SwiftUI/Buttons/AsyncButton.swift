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

public struct AsyncButton<RegularView, LoadingView>: View
where RegularView: View, LoadingView: View {

  @State private var runningTask: Task<Void, Never>?
  private let role: ButtonRole?
  private let action: () async throws -> Void
  private let regularLabel: () -> RegularView
  private let loadingLabel: () -> LoadingView

  public init(
    role: ButtonRole? = .none,
    @_inheritActorContext action: @escaping () async throws -> Void,
    @ViewBuilder regularLabel: @escaping () -> RegularView,
    @ViewBuilder loadingLabel: @escaping () -> LoadingView
  ) {
    self.role = role
    self.action = action
    self.regularLabel = regularLabel
    self.loadingLabel = loadingLabel
  }

  public init(
    role: ButtonRole? = .none,
    @_inheritActorContext action: @escaping () async throws -> Void,
    @ViewBuilder label: @escaping () -> RegularView
  ) where LoadingView == EmptyView {
    self.role = role
    self.action = action
    self.regularLabel = label
    self.loadingLabel = EmptyView.init
  }

  public var body: some View {
    Button(
      role: self.role,
      action: {
        if case .none = self.runningTask {
          self.runningTask = .detached { @MainActor [action] () async -> Void in
            await consumingErrors {
              try await action()
            }
            self.runningTask = .none
          }
        }
        else {
          // ignore operation - already running
        }
      },
      label: {
        // use loading label if loading and defined
        if self.runningTask == nil || LoadingView.self == EmptyView.self {
          self.regularLabel()
            .contentShape(.interaction, Rectangle())
        }
        else {
          self.loadingLabel()
            .contentShape(.interaction, Rectangle())
        }
      }
    )
  }
}

#if DEBUG
internal struct AsyncButton_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack {
      AsyncButton(
        action: {
          print("TAP")
          try? await Task.sleep(nanoseconds: 1500 * NSEC_PER_MSEC)
        },
        regularLabel: {
          Text("Tap me")
        },
        loadingLabel: {
          HStack {
            Text("Loading...")
            SwiftUI.ProgressView()
              .progressViewStyle(.circular)
          }
        }
      )

      AsyncButton(
        action: {
          try? await Task.never()
        },
        label: {
          Text("Infinite")
        }
      )

      AsyncButton(
        action: {
          try? await Task.never()
        },
        regularLabel: {
          Text("Infinite")
        },
        loadingLabel: {
          HStack(spacing: 8) {
            SwiftUI.ProgressView()
              .progressViewStyle(.circular)
            Text("Loading...")
          }
        }
      )
    }
  }
}
#endif
