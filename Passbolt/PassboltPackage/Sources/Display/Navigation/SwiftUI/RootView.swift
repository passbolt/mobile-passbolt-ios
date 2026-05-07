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

/// Root container view that observes RootNavigationState and renders the current root view.
/// Optionally wraps the root in a NavigationContainer for navigation stack support.
public struct RootView<FallbackContent: View>: View {

  @ObservedObject private var rootState: RootNavigationState
  private let fallback: () -> FallbackContent

  public init(
    rootState: RootNavigationState,
    @ViewBuilder fallback: @escaping () -> FallbackContent
  ) {
    self.rootState = rootState
    self.fallback = fallback
  }

  public var body: some View {
    Group {
      if let root = rootState.currentRoot {
        if rootState.useNavigationStack {
          NavigationContainer(navigationState: rootState.navigationState) {
            root.makeView()
          }
          .id(root.id)
        }
        else {
          root.makeView()
            .id(root.id)
        }
      }
      else {
        fallback()
      }
    }
    .animation(.easeInOut(duration: 0.3), value: rootState.currentRoot?.id)
  }
}
