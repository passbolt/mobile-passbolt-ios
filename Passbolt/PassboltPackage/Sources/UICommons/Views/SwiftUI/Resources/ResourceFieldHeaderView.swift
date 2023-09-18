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

public struct ResourceFieldHeaderView: View {

  private let name: DisplayableString
  private let requiredMark: Bool
  private let encryptedMark: Bool?

  public init(
    name: DisplayableString,
    requiredMark: Bool = false,
    encryptedMark: Bool? = .none
  ) {
    self.name = name
    self.requiredMark = requiredMark
    self.encryptedMark = encryptedMark
  }

  public var body: some View {
    switch (self.requiredMark, self.encryptedMark) {
    case (false, .none):
      Text(displayable: self.name)
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )
        .lineLimit(1)
        .frame(
          maxWidth: .infinity,
          minHeight: 12,
          alignment: .leading
        )

    case (true, .none):
      (Text(displayable: self.name)
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )
        + Text("*")
        .text(
          font: .inter(
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltSecondaryRed
        ))
        .lineLimit(1)
        .frame(
          maxWidth: .infinity,
          minHeight: 12,
          alignment: .leading
        )

    case (true, .some(let encrypted)):
      HStack(spacing: 0) {
        (Text(displayable: self.name)
          .text(
            font: .inter(
              ofSize: 12,
              weight: .semibold
            ),
            color: .passboltPrimaryText
          )
          + Text("*")
          .text(
            font: .inter(
              ofSize: 12,
              weight: .semibold
            ),
            color: .passboltSecondaryRed
          ))
          .lineLimit(1)
          .frame(
            maxWidth: .infinity,
            minHeight: 12,
            alignment: .leading
          )

        Image(
          named: encrypted
            ? .lockedLock
            : .unlockedLock
        )
        .resizable(resizingMode: .stretch)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 12)
      }

    case (false, .some(let encrypted)):
      HStack(spacing: 0) {
        Text(displayable: self.name)
          .text(
            font: .inter(
              ofSize: 12,
              weight: .semibold
            ),
            color: .passboltPrimaryText
          )
          .lineLimit(1)
          .frame(
            maxWidth: .infinity,
            minHeight: 12,
            alignment: .leading
          )

        Image(
          named: encrypted
            ? .lockedLock
            : .unlockedLock
        )
        .resizable(resizingMode: .stretch)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 12)
      }
    }
  }
}

struct ResourceFieldHeaderView_Previews: PreviewProvider {

  static var previews: some View {
    VStack {
      ResourceFieldHeaderView(
        name: "Aaaa",
        requiredMark: false,
        encryptedMark: .none
      )

      ResourceFieldHeaderView(
        name: "Bbbb",
        requiredMark: true,
        encryptedMark: .none
      )

      ResourceFieldHeaderView(
        name: "Cccc",
        requiredMark: false,
        encryptedMark: false
      )

      ResourceFieldHeaderView(
        name: "Dddd",
        requiredMark: false,
        encryptedMark: true
      )

      ResourceFieldHeaderView(
        name: "Eeee",
        requiredMark: true,
        encryptedMark: false
      )

      ResourceFieldHeaderView(
        name: "Ffff",
        requiredMark: true,
        encryptedMark: true
      )
    }
  }
}
