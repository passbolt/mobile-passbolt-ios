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
import UIKit

public final class LetterIconView: PlainView {

  private let label: Label = .init()

  public init(text: String = "") {
    super.init()
    self.update(from: text)
  }

  @available(*, unavailable) @_disfavoredOverload
  public required init() {
    unreachable(#function)
  }

  public override func setup() {
    super.setup()

    mut(label) {
      .combined(
        .font(.inter(ofSize: 14, weight: .medium)),
        .backgroundColor(.clear),
        .numberOfLines(1),
        .textAlignment(.center),
        .subview(of: self),
        .edges(equalTo: self, usingSafeArea: false)
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(.clear),
        .cornerRadius(4, masksToBounds: true),
        .aspectRatio(1)
      )
    }
  }

  public func update(
    from text: String
  ) {
    // First letters of first two words uppercased
    let letters: String =
      text
      .split(separator: " ")
      .prefix(2)
      .compactMap { $0.first?.uppercased() }
      .joined()

    let color: UIColor = colors[abs(text.hash) % colors.count]
    mut(label) {
      .combined(
        .text(letters),
        .textColor(color),
        .backgroundColor(color.withAlphaComponent(0.3))
      )
    }
  }
}

// List of colors used to generate background colors for icon.
private let colors: Array<UIColor> = [
  .init(0xe57373),
  .init(0xf06292),
  .init(0xba68c8),
  .init(0x9575cd),
  .init(0x7986cb),
  .init(0x64b5f6),
  .init(0x4fc3f7),
  .init(0x4dd0e1),
  .init(0x4db6ac),
  .init(0x81c784),
  .init(0xaed581),
  .init(0xff8a65),
  .init(0xd4e157),
  .init(0xffd54f),
  .init(0xffb74d),
  .init(0xa1887f),
  .init(0x90a4ae),
]

extension LetterIconView: UIViewRepresentable {

  public typealias UIViewType = LetterIconView

  public func makeUIView(
    context: Context
  ) -> Self {
    self
  }

  public func updateUIView(
    _ uiView: LetterIconView,
    context: Context
  ) {
    // NOP
  }
}
