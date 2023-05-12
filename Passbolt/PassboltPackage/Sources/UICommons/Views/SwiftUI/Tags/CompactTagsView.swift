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

import CommonModels
import SwiftUI

public struct CompactTagsView: View {

  private let tags: Array<String>

  public init(
    tags: Array<String>
  ) {
    self.tags = tags
  }

  public var body: some View {
    if #available(iOS 16, *) {
      self.contentView()
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
    else {
      self.contentViewLegacy()
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
    }
  }

  @available(iOS 16, *)
  @ViewBuilder @MainActor private func contentView() -> some View {
    // it will be available to use custom Layout
    // from iOS 16 after switching to Xcode 14
    // it has to be legacy version always for now
    self.contentViewLegacy()
  }

  @ViewBuilder @MainActor private func contentViewLegacy() -> some View {
    HStack(spacing: 4) {
      switch self.tags.count {
      case 0:
        Color.clear
          .frame(height: 18)

      case 1:
        self.tagView(self.tags[0])

      case _:  // > 1
        self.tagView(self.tags[0])
        self.tagView("+\(self.tags.count - 1)")
      }
    }
  }

  @ViewBuilder @MainActor private func tagView(
    _ tag: String
  ) -> some View {
    Text(tag)
      .multilineTextAlignment(.leading)
      .lineLimit(1)
      .padding(
        top: 2,
        leading: 4,
        bottom: 2,
        trailing: 4
      )
      .text(
        font: .inter(
          ofSize: 14,
          weight: .semibold
        ),
        color: .passboltPrimaryText
      )
      .backgroundColor(.passboltDivider)
      .cornerRadius(2)
  }
}

#if DEBUG

internal struct CompactTagsStackView_Previews: PreviewProvider {

  internal static var previews: some View {
    CompactTagsView(
      tags: [
        "#Tag",
        "Another",
        "Test",
        "More",
        "Loooooooooong",
        "Loooooooooong",
        "Loooooooooong",
        "Loooooooooong",
        "Loooooooooooooooooooooooooooooooong",
      ]
    )
  }
}
#endif
