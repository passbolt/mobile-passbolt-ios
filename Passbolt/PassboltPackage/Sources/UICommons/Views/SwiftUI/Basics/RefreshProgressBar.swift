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

/// A determinate refresh progress bar driven by the session-data refresh stream.
///
/// The source is a single optional: `nil` while idle, `.some(fraction)` in `0...1` while refreshing.
/// Shows a `LinearProgressBar` during a refresh; on successful completion it briefly holds the
/// finished bar at 100% before hiding, so the completed state is visible; on failure (or any refresh
/// that never reaches 100%) it hides immediately. Renders nothing when idle, so it is safe to place
/// in a `safeAreaInset` or `overlay`. Reused across the resource lists and details.
public struct RefreshProgressBar: View {

  /// How long the completed (100%) bar lingers before hiding on success.
  private static let completedLingerNanoseconds: UInt64 = 400_000_000

  private let source: AnyUpdatable<Double?>?
  @State private var refreshing: Bool = false
  @State private var progress: Double = 0
  @State private var visible: Bool = false

  /// - Parameter source: Emits `nil` when idle and `.some(fraction)` in `0...1` while refreshing
  ///   (`SessionData.refreshProgress`).
  public init(source: AnyUpdatable<Double?>?) {
    self.source = source
  }

  public var body: some View {
    // A real container (not `Group`): `Group` distributes modifiers to its children, so when the
    // conditional content is absent the `.task` subscriptions below would never attach and the bar
    // would never appear. A `VStack` is itself a view, so the tasks run regardless of visibility.
    VStack(spacing: 0) {
      if self.visible && self.source != nil {
        LinearProgressBar(progress: self.progress)
      }
    }
    .task {
      guard let source: AnyUpdatable<Double?> = self.source
      else { return }
      var iterator: UpdatableIterator<Double?> = source.makeAsyncIterator()
      while let update: Update<Double?> = await iterator.next() {
        let value: Double? = (try? update.value) ?? nil
        // A refresh always starts by emitting `.some(0)`, so `progress` is 0 by the time the bar is
        // shown — no stale-100% flash, and no need to reset it on show.
        if let fraction: Double = value {
          self.progress = fraction
        }
        withAnimation(.easeInOut(duration: 0.25)) {
          self.refreshing = value != nil
        }
      }
    }
    .task(id: self.refreshing) {
      if self.refreshing {
        withAnimation(.easeInOut(duration: 0.25)) {
          self.visible = true
        }
      }
      else if self.visible {
        // Refresh ended. Hold the bar only if it actually completed (reached 100%). Because a single
        // ordered stream delivers the final 1.0 before the terminating nil, `progress` is already
        // authoritative here — no cross-stream race to work around.
        if self.progress >= 1.0 {
          try? await Task.sleep(nanoseconds: Self.completedLingerNanoseconds)
        }
        // A refresh starting during the wait changes `refreshing` and cancels this task; `Task.sleep`
        // throws on cancellation but `try?` swallows it, so bail out explicitly — otherwise we would
        // hide the bar the next run just showed.
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
          self.visible = false
        }
      }
    }
  }
}
