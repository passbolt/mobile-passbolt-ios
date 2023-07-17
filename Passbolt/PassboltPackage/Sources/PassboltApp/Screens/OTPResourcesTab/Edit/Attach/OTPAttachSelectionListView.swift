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
import UICommons

internal struct OTPAttachSelectionListView: ControlledView {

  internal let controller: OTPAttachSelectionListViewController

  internal init(
    controller: OTPAttachSelectionListViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.confirmationAlert,
      alert: { alert in
        switch alert {
        case .attach:
          return AlertViewModel(
            title: "otp.attach.alert.attach.title",
            message: "otp.attach.alert.attach.message",
            actions: [
              .cancel(),
              .regular(
                title: "otp.attach.alert.attach.button.title",
                perform: self.controller.sendForm
              ),
            ]
          )

        case .replace:
          return AlertViewModel(
            title: "otp.attach.alert.replace.title",
            message: "otp.attach.alert.replace.message",
            actions: [
              .cancel(),
              .regular(
                title: "otp.attach.alert.replace.button.title",
                perform: self.controller.sendForm
              ),
            ]
          )
        }
      }
    ) {
      withSnackBarMessage(\.snackBarMessage) {
        VStack(spacing: 0) {
          self.search
          self.list
          self.actionButton
        }
      }
    }
    .frame(maxHeight: .infinity)
    .navigationTitle(
      displayable: "otp.attach.list.title"
    )
  }

  @MainActor @ViewBuilder internal var search: some View {
    with(\.searchText) { (searchText: String) in
      SearchView(
        prompt: "resources.search.placeholder",
        text: self.binding(
          to: \.searchText,
          updating: self.controller.setSearch(text:)
        )
      )
    }
    .padding(16)
  }
  @MainActor @ViewBuilder internal var list: some View {
    CommonList {
      CommonListSection {
        withEach(\.listItems) { item in
          CommonListRow(
            contentAction: {
              self.controller.select(item)
            },
            content: {
              HStack(spacing: 8) {
                LetterIconView(text: item.name)
                  .frame(
                    width: 40,
                    height: 40,
                    alignment: .center
                  )
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                    .lineLimit(1)
                    .font(.inter(ofSize: 14, weight: .semibold))
                    .foregroundColor(Color.passboltPrimaryText)
                  Text(
                    item.username
                      ?? DisplayableString
                      .localized(key: "resource.list.username.empty.placeholder")
                      .string()
                  )
                  .lineLimit(1)
                  .font(
                    item.username == nil
                      ? .interItalic(ofSize: 12, weight: .regular)
                      : .inter(ofSize: 12, weight: .regular)
                  )
                  .foregroundColor(Color.passboltSecondaryText)
                }
              }
              .frame(height: 64)
            },
            accessory: {
              switch item.state {
              case .none:
                Image(named: .circleUnselected)
                  .foregroundColor(.passboltIcon)

              case .notAllowed:
                Image(named: .lockedLock)
                  .foregroundColor(.passboltIcon)

              case .selected:
                Image(named: .circleSelected)
                  .foregroundColor(.passboltPrimaryBlue)
              }
            }
          )
          .disabled(item.state.disabled)
        }
      }
    }
    .shadowTopAndBottomEdgeOverlay()
  }
  @MainActor @ViewBuilder internal var actionButton: some View {
    PrimaryButton(
      title: "generic.apply",
      action: self.controller.trySendForm
    )
    .padding(16)
  }
}
