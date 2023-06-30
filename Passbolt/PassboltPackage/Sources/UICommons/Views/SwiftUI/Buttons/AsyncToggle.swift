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

public struct AsyncToggle: View {

  @State private var runningTask: Task<Void, Never>?
  private let state: Bool
  private let toggle: (Bool) async -> Void

  public init(
    state: Bool,
    @_inheritActorContext toggle: @escaping (Bool) async -> Void
  ) {
    self.state = state
    self.toggle = toggle
  }

  public var body: some View {
    Toggle(
      isOn: .init(
        get: { self.state },
        set: { (newValue: Bool) in
          if case .none = self.runningTask {
            self.runningTask = .detached { @MainActor [state, toggle] () async -> Void in
              await toggle(!state)
              self.runningTask = .none
            }
          }
          else {
            // ignore operation - already running
          }
        }
      ),
      label: EmptyView.init
    )
    .overlay {
      // use loading label if loading
      if case .some = self.runningTask {
        SwiftUI.ProgressView()
          .progressViewStyle(.circular)
          .padding(
            // those values are found through
            // experiments on iOS 16,
            // it can differ between OS versions
            self.state
              ? .leading
              : .trailing,
            self.state
              ? 30
              : 10
          )
      }  // else NOP
    }
    .fixedSize(
      horizontal: true,
      vertical: false
    )
  }
}

#if DEBUG
internal struct AsyncToggle_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack(alignment: .center) {
      AsyncToggle(
        state: true,
        toggle: { _ in
          try? await Task.sleep(nanoseconds: 1500 * NSEC_PER_MSEC)
        }
      )

      AsyncToggle(
        state: false,
        toggle: { _ in
          try? await Task.never()
        }
      )

      AsyncToggle(
        state: true,
        toggle: { _ in
          try? await Task.never()
        }
      )
    }
  }
}
#endif
