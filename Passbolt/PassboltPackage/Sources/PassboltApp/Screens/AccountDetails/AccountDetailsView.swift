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

internal struct AccountDetailsView: ControlledView {
  internal var controller: AccountDetailsViewController

  internal init(
    controller: AccountDetailsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 0) {
      CommonList {
        self.headerView
        self.propertiesView
      }
      Spacer()
      self.bottomButtons
    }
    .navigationTitle(displayable: "account.details.title")
  }

  @MainActor @ViewBuilder private var propertiesView: some View {
    CommonListSection {
      CommonListRow(
        content: {
          self.labelInput
        }
      )

      CommonListRow(
        content: {
          self.with(\.name) { (name: String) in
            ResourceFieldView(
              name: "account.details.field.name.title",
              value: name
            )
          }
        }
      )

      CommonListRow(
        content: {
          self.with(\.username) { (username: String) in
            ResourceFieldView(
              name: "account.details.field.email.title",
              value: username
            )
          }
        }
      )
      self.with(\.role) { (role: String?) in
        if let role {
          CommonListRow(
            content: {
              ResourceFieldView(
                name: "account.details.field.role.title",
                value: role
              )
            }
          )
        }  // else NOP
      }

      CommonListRow(
        content: {
          self.with(\.domain) { (domain: String) in
            ResourceFieldView(
              name: "account.details.field.url.title",
              value: domain
            )
          }
        }
      )
    }
  }

  @MainActor @ViewBuilder private var headerView: some View {
    CommonListSection {
      HStack {
        Spacer()
        self.with(\.avatarImage) { (avatarImage: Data?) in
          AvatarView(avatarImage: avatarImage)
        }
        .frame(
          width: 96,
          height: 96,
          alignment: .center
        )
        .padding(
          top: 16,
          bottom: 16
        )
        Spacer()
      }
    }
  }

  @MainActor @ViewBuilder private var labelInput: some View {
    VStack(spacing: 8) {
      self.withValidatedBinding(
        \.currentAccountLabel,
        updating: self.controller.setCurrentAccountLabel(_:)
      ) { (label: Binding<Validated<String>>) in
        FormTextFieldView(
          title: "account.details.field.label.title",
          state: label
        )
      }
      Text(
        displayable: .localized(
          key: "account.details.field.label.editing.info"
        )
      )
      .font(.inter(ofSize: 12, weight: .regular))
      .text(
        font: .inter(ofSize: 12, weight: .regular),
        color: .passboltSecondaryText
      )
      .lineLimit(0)
    }
  }

  @MainActor @ViewBuilder private var bottomButtons: some View {
    VStack(spacing: 8) {
      PrimaryButton(
        title: "account.details.button.save.title",
        action: self.controller.saveChanges
      )
      SecondaryButton(
        title: "settings.accounts.item.export.title",
        action: self.controller.transferAccount
      )
    }
    .padding(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }
}
