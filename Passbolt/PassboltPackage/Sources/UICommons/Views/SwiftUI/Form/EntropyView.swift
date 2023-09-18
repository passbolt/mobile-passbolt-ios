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

import Crypto
import SwiftUI

public struct EntropyView: View {

  private let label: DisplayableString
  private let clipping: CGFloat
  private let color: Color

  public init(
    entropy: Entropy
  ) {
    switch entropy {
    case Entropy.zero ..< Entropy.veryWeakPassword:
      self.label = "resource.form.password.strength"
      self.clipping = 0.0
      self.color = .passboltSecondaryRed

    case Entropy.veryWeakPassword ..< Entropy.weakPassword:
      self.label = "resource.form.strength.very.weak"
      self.clipping = 0.1
      self.color = .passboltSecondaryRed

    case Entropy.weakPassword ..< Entropy.fairPassword:
      self.label = "resource.form.strength.weak"
      self.clipping = 0.4
      self.color = .passboltSecondaryRed

    case Entropy.fairPassword ..< Entropy.strongPassword:
      self.label = "resource.form.strength.fair"
      self.clipping = 0.6
      self.color = .passboltSecondaryOrange

    case Entropy.strongPassword ..< Entropy.veryStrongPassword:
      self.label = "resource.form.strength.strong"
      self.clipping = 0.8
      self.color = .passboltSecondaryGreen

    case Entropy.veryStrongPassword ..< Entropy.greatestFinite:
      self.label = "resource.form.strength.very.strong"
      self.clipping = 1.0
      self.color = .passboltSecondaryGreen

    case _:
      self.label = "resource.form.password.strength"
      self.clipping = 0.0
      self.color = .passboltSecondaryRed
    }
  }

  public var body: some View {
    VStack(spacing: 4) {
      GeometryReader { (proxy: GeometryProxy) in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.passboltDivider)
            .frame(
              width: proxy.size.width,
              height: proxy.size.height
            )

          Capsule()
            .fill(self.color)
            .frame(
              width: proxy.size.width * self.clipping,
              height: proxy.size.height
            )
        }
      }
      .frame(height: 6)
      .frame(maxWidth: .infinity)

      Text(displayable: self.label)
        .text(
          font: .inter(
            ofSize: 14,
            weight: .medium
          ),
          color: .passboltPrimaryText
        )
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
    .animation(.easeIn, value: self.clipping)
  }
}

struct EntropyView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      EntropyView(entropy: .veryStrongPassword)
      EntropyView(entropy: .strongPassword)
      EntropyView(entropy: .fairPassword)
      EntropyView(entropy: .weakPassword)
      EntropyView(entropy: .veryWeakPassword)
      EntropyView(entropy: .zero)
    }
  }
}
