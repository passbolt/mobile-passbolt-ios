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

public struct FolderLocationView: View {

  private let location: String

  public init(
    locationElements: Array<String>
  ) {
    self.location = locationElements.reduce(
      into:
        DisplayableString
        .localized(
          key: "folder.root.name"
        )
        .string()
    ) { (result: inout String, element: String) in
      result.append(" › \(element)")
    }
  }

  public var body: some View {
    Text(self.location)
      .text(
        font: .inter(
          ofSize: 14,
          weight: .regular
        ),
        color: Color.passboltSecondaryText
      )
      .truncationMode(.middle)
      .multilineTextAlignment(.leading)
      .lineLimit(1)
      .frame(
        maxWidth: .infinity,
        alignment: .topLeading
      )
  }
}

#if DEBUG

internal struct FolderLocationView_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack(spacing: 8) {
      FolderLocationView(
        locationElements: [
          "root"
        ]
      )

      FolderLocationView(
        locationElements: [
          "root",
          "folder 1",
          "folder 2",
          "folder 3",
          "folder 4",
          "folder 5",
        ]
      )

      FolderLocationView(
        locationElements: [
          "root",
          "folder 1",
          "folder 2",
          "folder 3",
          "folder 4",
          "folder 5",
          "folder 6",
          "folder 7",
          "folder 8",
          "folder 9",
          "folder 10",
        ]
      )
    }
    .padding(8)
  }
}

#endif
