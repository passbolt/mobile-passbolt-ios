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

public struct ResourceRelativeDateViewModel {
  let relativeDate: String
  let intervalNumber: String
  let pastDatePrefix: DisplayableString?
  let futureDatePrefix: DisplayableString?
  let isPastDate: Bool

  public init(
    relativeDate: String,
    intervalNumber: String,
    pastDatePrefix: DisplayableString?,
    futureDatePrefix: DisplayableString?,
    isPastDate: Bool
  ) {
    self.relativeDate = relativeDate
    self.intervalNumber = intervalNumber
    self.pastDatePrefix = pastDatePrefix
    self.futureDatePrefix = futureDatePrefix
    self.isPastDate = isPastDate
  }
}

public struct ResourceRelativeDateView: View {

  private let viewModel: ResourceRelativeDateViewModel

  public init(viewModel: ResourceRelativeDateViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    HStack(spacing: 4.0) {
      Text(displayable: viewModel.isPastDate ? viewModel.pastDatePrefix ?? "" : viewModel.futureDatePrefix ?? "")
        .text(
          font: .inter(
            ofSize: 12,
            weight: .regular
          ),
          color: Color.passboltSecondaryText
        )
      Text("\(viewModel.intervalNumber)")
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
            ofSize: 12,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )
        .backgroundColor(.passboltDivider)
        .cornerRadius(2)
      Text(viewModel.relativeDate)
        .text(
          font: .inter(
            ofSize: 12,
            weight: .regular
          ),
          color: Color.passboltSecondaryText
        )
    }
  }
}

#if DEBUG

internal struct ResourceRelativeDateView_Previews: PreviewProvider {

  internal static var previews: some View {
    ResourceRelativeDateView(
      viewModel: ResourceRelativeDateViewModel(
        relativeDate: "days ago",
        intervalNumber: "4",
        pastDatePrefix: "Expired",
        futureDatePrefix: nil,
        isPastDate: true
      )
    )
  }
}
#endif
