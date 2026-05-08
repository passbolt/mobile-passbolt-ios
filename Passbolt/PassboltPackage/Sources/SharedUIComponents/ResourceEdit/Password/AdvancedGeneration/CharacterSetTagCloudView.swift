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

import Display
import SwiftUI

internal struct CharacterSetTagCloudView: View {

  internal struct Item: Identifiable {
    internal let id: String
    internal let label: String
    internal let isOn: Bool
    internal let toggle: @MainActor () -> Void
  }

  private let items: Array<Item>
  private let horizontalSpacing: CGFloat
  private let verticalSpacing: CGFloat

  internal init(
    items: Array<Item>,
    horizontalSpacing: CGFloat = 8,
    verticalSpacing: CGFloat = 8
  ) {
    self.items = items
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
  }

  internal var body: some View {
    FlowLayout(horizontalSpacing: self.horizontalSpacing, verticalSpacing: self.verticalSpacing) {
      ForEach(self.items, id: \.id) { (item: Item) in
        self.tagButton(for: item)
      }
    }
  }

  @ViewBuilder
  private func tagButton(for item: Item) -> some View {
    Button(
      action: item.toggle,
      label: {
        Text(item.label)
          .font(.inter(ofSize: 14, weight: .medium))
          .foregroundColor(item.isOn ? .passboltPrimaryButtonText : .passboltPrimaryText)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(minHeight: 36)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(item.isOn ? Color.passboltPrimaryBlue : Color.passboltBackgroundAlternative)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(item.isOn ? Color.passboltPrimaryBlue : Color.passboltDivider, lineWidth: 1)
          )
      }
    )
    .buttonStyle(.plain)
  }
}

internal struct FlowLayout: Layout {

  internal var horizontalSpacing: CGFloat
  internal var verticalSpacing: CGFloat

  internal init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
  }

  internal func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) -> CGSize {
    let maxWidth: CGFloat = proposal.width ?? .infinity
    let layout: LayoutResult = self.computeLayout(maxWidth: maxWidth, subviews: subviews)
    return CGSize(width: layout.width, height: layout.height)
  }

  internal func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) {
    let layout: LayoutResult = self.computeLayout(maxWidth: bounds.width, subviews: subviews)
    for (index, position) in layout.positions.enumerated() {
      subviews[index]
        .place(
          at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
          anchor: .topLeading,
          proposal: ProposedViewSize(layout.sizes[index])
        )
    }
  }

  private struct LayoutResult {
    var positions: Array<CGPoint>
    var sizes: Array<CGSize>
    var width: CGFloat
    var height: CGFloat
  }

  private func computeLayout(maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
    var positions: Array<CGPoint> = .init()
    var sizes: Array<CGSize> = .init()
    var rowWidth: CGFloat = 0
    var rowHeight: CGFloat = 0
    var totalHeight: CGFloat = 0
    var maxRowWidth: CGFloat = 0

    for subview in subviews {
      let size: CGSize = subview.sizeThatFits(.unspecified)
      sizes.append(size)
      let leadingSpacing: CGFloat = rowWidth == 0 ? 0 : self.horizontalSpacing
      if rowWidth + leadingSpacing + size.width > maxWidth, rowWidth > 0 {
        // wrap
        totalHeight += rowHeight + self.verticalSpacing
        maxRowWidth = max(maxRowWidth, rowWidth)
        rowWidth = 0
        rowHeight = 0
      }
      let xPosition: CGFloat = rowWidth == 0 ? 0 : rowWidth + self.horizontalSpacing
      positions.append(CGPoint(x: xPosition, y: totalHeight))
      rowWidth = xPosition + size.width
      rowHeight = max(rowHeight, size.height)
    }
    maxRowWidth = max(maxRowWidth, rowWidth)
    totalHeight += rowHeight
    return LayoutResult(
      positions: positions,
      sizes: sizes,
      width: maxRowWidth,
      height: totalHeight
    )
  }
}
