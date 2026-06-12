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

extension Text {

  /// Resolves `displayable`, parses its inline markdown (e.g. `**bold**`) and applies the Inter
  /// font per run — `boldWeight` to strongly emphasized runs, `weight` to the rest.
  ///
  /// SwiftUI parses markdown only for `LocalizedStringKey` values, and even then it cannot
  /// synthesize a bold variant from the specifically-named `Font.inter` faces. This builds a
  /// styled `AttributedString` explicitly so emphasis renders with the matching Inter weight.
  ///
  /// - Note: `UICommons` declares its own `enum AttributedString`, so the SwiftUI type is
  ///   referenced as `SwiftUI.AttributedString` throughout.
  public init(
    localizedMarkdown displayable: DisplayableString,
    size: CGFloat,
    color: Color,
    weight: Font.Weight = .regular,
    boldWeight: Font.Weight = .bold,
    arguments: CVarArg...
  ) {
    let raw: String = displayable.string(with: arguments)
    var attributed: SwiftUI.AttributedString
    do {
      attributed = try SwiftUI.AttributedString(
        markdown: raw,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
      )
    }
    catch {
      attributed = SwiftUI.AttributedString(raw)
    }

    for run: SwiftUI.AttributedString.Runs.Run in attributed.runs {
      let isBold: Bool = run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false
      attributed[run.range].font = .inter(ofSize: size, weight: isBold ? boldWeight : weight)
      attributed[run.range].foregroundColor = color
    }

    self.init(attributed)
  }
}
