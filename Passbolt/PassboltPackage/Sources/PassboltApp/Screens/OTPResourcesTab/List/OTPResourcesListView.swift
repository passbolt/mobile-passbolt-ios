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

internal struct OTPResourcesListView: ControlledView {

  internal let controller: OTPResourcesListViewController

  internal init(
    controller: OTPResourcesListViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    ScreenView(
      titleIcon: .otp,
      title: "otp.resources.list.title",
      contentView: {
        WithViewState(
          from: self.controller,
          at: \.snackBarMessage
        ) { _ in
          VStack(spacing: 0) {
            self.search
            self.list
          }
          .snackBarMessage(
            with: self.binding(to: \.snackBarMessage)
          )
        }
      }
    )
    .backgroundColor(.passboltBackground)
    .foregroundColor(.passboltPrimaryText)
    .onDisappear(perform: self.controller.hideOTPCodes)
  }

  @ViewBuilder @MainActor private var search: some View {
    with(\.searchText) { (searchText: String) in
      SearchView(
        prompt: "otp.resources.search.placeholder",
        text: self.binding(
          to: \.searchText,
          updating: self.controller.setSearch(text:)
        ),
        rightAccessory: {
          AsyncButton(
            action: self.controller.showAccountMenu,
            regularLabel: {
              with(\.accountAvatarImage) { (accountAvatarImage: Data?) in
                UserAvatarView(
                  imageData: accountAvatarImage
                )
              }
            }
          )
        }
      )
    }
    .padding(
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }

  @ViewBuilder @MainActor private var createOTP: some View {
    AsyncButton(
      action: self.controller.createOTP,
      regularLabel: {
        HStack(spacing: 12) {
          Image(named: .create)
            .resizable()
            .frame(
              width: 40,
              height: 40
            )

          Text(
            displayable: .localized(
              key: .create
            )
          )
          .font(
            .inter(
              ofSize: 14,
              weight: .semibold
            )
          )
          .multilineTextAlignment(.leading)
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
        }
      }
    )
    .foregroundColor(Color.passboltPrimaryBlue)
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .commonListRowModifiers()
  }

  @ViewBuilder @MainActor private var emptyListPlaceholder: some View {
    VStack(
      alignment: .center,
      spacing: 12
    ) {
      Text(displayable: "otp.resources.list.empty.message")
        .multilineTextAlignment(.center)
        .font(
          .inter(
            ofSize: 20,
            weight: .semibold
          )
        )

      Image(named: .emptyState)
    }
    .frame(
      maxWidth: .infinity,
      alignment: .center
    )
    .listRowSeparator(.hidden)
    .listRowInsets(
      EdgeInsets(
        top: 32,
        leading: 16,
        bottom: 12,
        trailing: 16
      )
    )
  }

  @ViewBuilder @MainActor private var list: some View {
    CommonList {
      self.createOTP

      withEach(\.otpResources.values) { (item: TOTPResourceViewModel) in
        TOTPResourcesListRowView(
          title: item.name,
          generateTOTP: item.generateTOTP,
          action: {
            await self.controller.revealAndCopyOTP(for: item.id)
          },
          accessory: {
            AsyncButton(
              action: {
                await self.controller.showCentextualMenu(for: item.id)
              },
              regularLabel: {
                Image(named: .more)
                  .resizable()
                  .frame(
                    width: 20,
                    height: 20
                  )
              }
            )
          }
        )
      } placeholder: {
        self.emptyListPlaceholder
      }
    }
    .refreshable(action: self.controller.refreshList)
    .shadowTopEdgeOverlay()
  }
}
