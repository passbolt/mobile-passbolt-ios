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

  private let controller: OTPResourcesListController

  internal init(
    controller: OTPResourcesListController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(
      from: self.controller,
      at: \.snackBarMessage
    ) { _ in
      VStack(spacing: 0) {
        self.search
        self.list
      }
      .snackBarMessage(
        with: self.controller
          .binding(to: \.snackBarMessage)
      )
    }
    .backgroundColor(.passboltBackground)
    .foregroundColor(.passboltPrimaryText)
    .onDisappear(perform: self.controller.hideOTPCodes)
  }

  @ViewBuilder @MainActor private var search: some View {
    WithViewState(
      from: self.controller,
      at: \.searchText
    ) { (searchText: String) in
      SearchView(
        prompt: .localized(
          key: "otp.resources.search.placeholder"
        ),
        text: self.controller
          .binding(to: \.searchText),
        rightAccessory: {
          Button(
            action: self.controller.showAccountMenu,
            label: {
              WithViewState(
                from: self.controller,
                at: \.accountAvatarImage
              ) { (accountAvatarImage: Data?) in
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
      top: 8,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }

  @ViewBuilder @MainActor private var createOTP: some View {
    Button(
      action: self.controller.addOTP,
      label: {
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
      Text(
        displayable: .localized(
          key: "otp.resources.list.empty.message"
        )
      )
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

      WithViewState(
        from: self.controller,
        at: \.otpResources
      ) { (resources: Array<TOTPResourceViewModel>) in
        if resources.isEmpty {
          self.emptyListPlaceholder
        }
        else {
          ForEach(resources) { (resource: TOTPResourceViewModel) in
            TOTPResourcesListRowView(
              title: resource.name,
              value: resource.totpValue,
              action: {
                self.controller.revealAndCopyOTP(resource.id)
              },
              accessory: {
                Button(
                  action: {
                    self.controller.showCentextualMenu(resource.id)
                  },
                  label: {
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
          }
        }
      }
    }
    .refreshable(action: self.controller.refreshList)
    .shadowTopEdgeOverlay()
  }
}
