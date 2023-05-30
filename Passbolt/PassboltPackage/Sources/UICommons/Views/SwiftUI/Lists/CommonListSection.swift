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

public struct CommonListSection<Header, Content>: View
where Header: View, Content: View {

  private let header: @MainActor () -> Header
  private let content: @MainActor () -> Content

  public init(
    @ViewBuilder header: @escaping @MainActor () -> Header,
    @ViewBuilder content: @escaping @MainActor () -> Content
  ) {
    self.header = header
    self.content = content
  }

  public init(
    @ViewBuilder content: @escaping () -> Content
  ) where Header == EmptyView {
    self.header = EmptyView.init
    self.content = content
  }

  public var body: some View {
    Section(
      content: self.content,
      header: {
        self.header()
          .frame(
            minHeight: 16,
            idealHeight: 16,
            alignment: .bottomLeading
          )
      }
    )
    .textCase(.none)  // prevents uppercased section header text
    .listSectionSeparator(.hidden)  // removes separators
    .listRowSeparator(.hidden)  // removes separators
    .listRowInsets(EdgeInsets())  // removes default padding
    .buttonStyle(.plain)  // prevents list selection UI
    .padding(
      leading: 16,
      trailing: 16
    )
  }
}
