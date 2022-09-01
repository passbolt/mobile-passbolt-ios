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

private struct Loader: ViewModifier {

  private var visible: Bool

  fileprivate init(
    visible: Bool
  ) {
    self.visible = visible
  }

  fileprivate func body(
    content: Content
  ) -> some View {
    if self.visible {
      content
        .overlay(
          ZStack {
            Color
              .passboltSheetBackground
              .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
              )
            VStack(spacing: 4) {
              SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
              Text(
                displayable: .localized(
                  key: .loading
                )
              )
              .text(
                font: .inter(
                  ofSize: 12,
                  weight: .medium
                ),
                color: .passboltPrimaryText
              )
            }
            .frame(
              width: 96,
              height: 96
            )
            .backgroundColor(.passboltBackgroundLoader)
            .cornerRadius(8)
          }
          .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
          )
          .ignoresSafeArea()
          .allowsHitTesting(true)
        )
        .disabled(true)
    }
    else {
      content
    }
  }
}

extension View {

  public func loader(
    visible: Bool
  ) -> some View {
    ModifiedContent(
      content: self,
      modifier: Loader(
        visible: visible
      )
    )
  }
}

#if DEBUG

internal struct Loader_Previews: PreviewProvider {

  internal static var previews: some View {
    Text("Lorem ipsum dolor sit amet")
      .loader(visible: true)
      .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
      )
  }
}
#endif
