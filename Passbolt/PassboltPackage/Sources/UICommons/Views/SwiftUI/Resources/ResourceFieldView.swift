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

public struct ResourceFieldView<ContentView>: View
where ContentView: View {

  private let name: DisplayableString
  private let requiredMark: Bool
  private let encryptedMark: Bool?
  private let content: @MainActor () -> ContentView

  public init(
    name: DisplayableString,
    requiredMark: Bool = false,
    encryptedMark: Bool? = .none,
    @ViewBuilder content: @escaping @MainActor () -> ContentView
  ) {
    self.name = name
    self.requiredMark = requiredMark
    self.encryptedMark = encryptedMark
    self.content = content
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: 8
    ) {
      ResourceFieldHeaderView(
        name: self.name,
        requiredMark: self.requiredMark,
        encryptedMark: self.encryptedMark
      )
      self.content()
        .frame(minHeight: 24)
    }
    .padding(
      top: 12,
      bottom: 12
    )
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }
}
