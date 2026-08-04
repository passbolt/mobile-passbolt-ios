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

/// A thin, determinate horizontal progress bar: a blue fill over a faint track, sized to `progress`.
/// The `.easeInOut` animation on the fill width keeps it gliding smoothly between discrete progress
/// updates, so the bar always appears to move.
public struct LinearProgressBar: View {

  private let progress: Double
  private let height: Double

  /// - Parameters:
  ///   - progress: Fraction filled, clamped to `0.0 ... 1.0`.
  ///   - height: Bar thickness in points.
  public init(
    progress: Double,
    height: Double = 3
  ) {
    self.progress = min(max(progress, 0), 1)
    self.height = height
  }

  public var body: some View {
    GeometryReader { (proxy: GeometryProxy) in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.passboltDivider)
          .frame(
            width: proxy.size.width,
            height: proxy.size.height
          )

        Capsule()
          .fill(Color.passboltPrimaryBlue)
          .frame(
            width: proxy.size.width * self.progress,
            height: proxy.size.height
          )
      }
    }
    .frame(height: self.height)
    .frame(maxWidth: .infinity)
    .animation(.easeInOut, value: self.progress)
  }
}

#if DEBUG

internal struct LinearProgressBar_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack(spacing: 24) {
      LinearProgressBar(progress: 0)
      LinearProgressBar(progress: 0.35)
      LinearProgressBar(progress: 1)
    }
    .padding()
  }
}
#endif
