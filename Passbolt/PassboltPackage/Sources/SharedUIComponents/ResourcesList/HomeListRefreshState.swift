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

extension View {

  private static var identifier: String { "home.list.collection.view" }

  /// Exposes a home list's refresh state to UI/E2E tests as an accessibility value
  /// (`"refreshing"` / `"idle"`) on a stable container identifier. See `WaitForRefreshToComplete`.
  public func homeListRefreshState(
    source: AnyUpdatable<Bool>?
  ) -> some View {
    self.modifier(
      HomeListRefreshStateModifier(
        identifier: Self.identifier,
        source: source
      )
    )
  }
}

private struct HomeListRefreshStateModifier: ViewModifier {

  fileprivate let identifier: String
  fileprivate let source: AnyUpdatable<Bool>?

  /// Mirrors `source` so the refresh state can be exposed to UI/E2E tests as an accessibility value.
  @State private var isRefreshing: Bool = false

  fileprivate func body(content: Content) -> some View {
    content
      .accessibilityIdentifier(self.identifier)
      .accessibilityValue(self.isRefreshing ? "refreshing" : "idle")
      .task {
        guard let source: AnyUpdatable<Bool> = self.source
        else { return }
        var iterator: UpdatableIterator<Bool> = source.makeAsyncIterator()
        while let update: Update<Bool> = await iterator.next() {
          self.isRefreshing = (try? update.value) ?? false
        }
      }
  }
}
