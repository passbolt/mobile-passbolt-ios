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

extension Text {

  @MainActor public func obfuscated(ofSize size: CGFloat) -> some View {
    self
      .font(.obfuscation(ofSize: size))
      .unclippedTextRenderer()
  }
}

@available(iOS 18.0, *)
private struct UnclippedTextRenderer: TextRenderer {
  fileprivate func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
    for line in layout {
      ctx.draw(line)
    }
  }

  fileprivate func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize {
    text.sizeThatFits(proposal)
  }
}

extension View {

  ///  Use the unclipped text renderer for iOS 18 and above to prevent text from being clipped when using custom fonts with `Text`.
  @ViewBuilder
  fileprivate func unclippedTextRenderer() -> some View {
    if #available(iOS 18.0, *) {
      self.textRenderer(UnclippedTextRenderer())
    }
    else {
      self
    }
  }
}
