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

import Accounts
import Display
import SharedUIComponents

internal struct AccountMenuView: ControlledView {

  internal let controller: AccountMenuViewController

  internal init(controller: AccountMenuViewController) {
    self.controller = controller
  }

  internal var body: some View {
    DrawerMenu(
      closeTap: controller.dismiss,
      title: {
        Text(displayable: "account.menu.title")
      },
      content: {
        VStack(spacing: 12) {
          currentAccountView
            .padding(.horizontal, 8)
          Divider()
            .padding(.horizontal, 8)
          withEach(\.otherAccounts) { account in
            AsyncButton(
              action: {
                await controller.onAccountTap(account: account.account)
              },
              label: {
                profileView(account, isCurrent: false)
              }
            )
            .padding(.horizontal, 8)
          }
          DrawerMenuItemView(
            action: controller.presentManageAccounts,
            title: {
              Text(displayable: "account.menu.manage.accounts.button.title")
                .font(.inter(ofSize: 14, weight: .semibold))
                .foregroundStyle(Color.passboltPrimaryText)
                .padding(.leading, 8)
            },
            leftIcon: {
              Image(named: "Users")
                .resizable()
            },
            isSelected: false
          )
        }
      }
    )
  }

  private var currentAccountView: some View {
    whenUnwrapped(\.currentUser) { currentUser in
      VStack(alignment: .leading, spacing: 12) {
        profileView(currentUser, isCurrent: true)

        HStack(spacing: 12) {
          button(
            title: "account.menu.account.details.button.title",
            iconName: "User",
            action: controller.presentAccountDetails
          )

          button(
            title: "account.menu.sign.out.button.title",
            iconName: "SignOut",
            action: controller.signOut
          )
          .background(
            RoundedRectangle(cornerRadius: 4)
              .foregroundStyle(Color.passboltDivider)
          )
        }
      }
    }
  }

  private func button(
    title: DisplayableString,
    iconName: ImageNameConstant,
    action: @escaping () async -> Void
  ) -> some View {
    AsyncButton(
      action: action,
      label: {
        HStack(spacing: 8) {
          Image(named: iconName)
            .resizable()
            .frame(width: 20, height: 20)
          Text(displayable: title)
            .font(
              .inter(
                ofSize: 14,
                weight: .semibold
              )
            )
            .foregroundStyle(Color.passboltPrimaryText)
        }
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
        .padding(8)
      }
    )
    .backgroundColor(.clear)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .foregroundStyle(Color.passboltDivider)
    )
    .frame(height: 40)
  }

  private func profileView(_ account: Controller.AccountData, isCurrent: Bool) -> some View {
    HStack(spacing: 12) {
      AutoloadingAvatarView(resolveImage: account.loadAvatarData)
        .overlay(alignment: .topTrailing) {
          isCurrent
            ? Circle()
              .foregroundColor(Color.passboltSecondaryGreen)
              .frame(width: 10, height: 10)
              .overlay {
                Circle()
                  .stroke(Color.white, lineWidth: 2)
              }
            : nil
        }
      VStack(alignment: .leading, spacing: 4) {
        Text(account.username)
          .font(.inter(ofSize: 14, weight: .semibold))
          .foregroundStyle(Color.passboltPrimaryText)
        Text(account.email)
          .font(.inter(ofSize: 12, weight: .regular))
          .foregroundStyle(Color.passboltSecondaryText)
      }
      Spacer()
    }
  }
}

@MainActor
private struct AutoloadingAvatarView: View {

  @State private var currentImageData: Data?
  private let resolveImage: @Sendable () async throws -> Data?

  fileprivate init(
    resolveImage: @escaping @Sendable () async throws -> Data?
  ) {
    self.resolveImage = resolveImage
  }

  fileprivate var body: some View {
    AvatarView(avatarImage: currentImageData)
      .frame(width: 40, height: 40)
      .foregroundColor(.passboltPrimaryText)
      .tint(.passboltPrimaryText)
      .backgroundColor(.clear)
      .task {
        if let resolvedImage: Data = try? await self.resolveImage() {
          self.currentImageData = resolvedImage
        }  // else keep current
      }
  }
}
