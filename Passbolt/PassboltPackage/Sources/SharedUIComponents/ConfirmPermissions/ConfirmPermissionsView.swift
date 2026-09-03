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

import CommonModels
import Display
import UICommons

internal struct ConfirmPermissionsView: @MainActor ControlledView {

  internal let controller: ConfirmPermissionsController

  internal init(
    controller: ConfirmPermissionsController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      ScreenView(
        title: state.mode.title,
        loading: state.loading
      ) {
        self.contentView(with: state)
      }
      .tabbarHidden()
    }
  }

  @ViewBuilder private func contentView(
    with state: Controller.ViewState
  ) -> some View {
    VStack(spacing: 0) {
      if let ownershipWarning: DisplayableString = state.ownershipWarning {
        WarningView(message: ownershipWarning)
          .padding(top: 8, leading: 16, bottom: 8, trailing: 16)
          .accessibilityIdentifier("permissions.confirm.ownership.warning")
      }

      if let duplicateWarning: DisplayableString = state.duplicateWarning {
        WarningView(message: duplicateWarning)
          .padding(top: 8, leading: 16, bottom: 8, trailing: 16)
          .accessibilityIdentifier("permissions.confirm.duplicate.warning")
      }

      if state.rows.isEmpty {
        if state.mode.isEditable {
          self.addRecipientsRow
            .padding(.horizontal, 16)
        }
        EmptyListView(
          message: .localized(
            key: "resource.permission.confirm.empty.message"
          )
        )
      }
      else {
        CommonList {
          CommonListSection {
            if state.mode.isEditable {
              self.addRecipientsRow
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .buttonStyle(.plain)
            }

            // Keyed by recipient rather than by the whole row: changing a level must update a row in place,
            // not replace it (which would reset its swipe state and animate as a removal plus an insertion).
            ForEach(
              state.rows,
              id: \ConfirmPermissionRowItem.recipientID
            ) { (row: ConfirmPermissionRowItem) in
              self.rowView(for: row)
            }
          }
        }
      }

      VStack(spacing: 8) {
        PrimaryButton(
          title: .localized(
            key: "resource.permission.confirm.action.confirm"
          ),
          // `disabled:` only tints the button; the modifier below is what stops the tap.
          disabled: .constant(state.ownershipWarning != .none),
          action: self.controller.confirm
        )
        .disabled(state.ownershipWarning != .none)
        .accessibilityIdentifier("permissions.confirm.button")
        SecondaryButton(
          title: .localized(
            key: .cancel
          ),
          action: self.controller.cancel
        )
        .accessibilityIdentifier("permissions.confirm.cancel")
      }
      .padding(16)
    }
  }

  private var addRecipientsRow: some View {
    CommonListRow(
      contentAction: self.controller.addRecipients,
      content: {
        HStack(spacing: 8) {
          Image(named: .create)
            .resizable()
            .frame(width: 40, height: 40, alignment: .center)
          Text(displayable: .localized(key: "resource.permission.confirm.action.add"))
            .text(
              font: .inter(ofSize: 14, weight: .semibold),
              color: .passboltPrimaryText
            )
        }
      }
    )
    .padding(top: 8, bottom: 8)
    .frame(height: 64)
    .accessibilityIdentifier("permissions.confirm.add")
  }

  @ViewBuilder private func rowView(
    for row: ConfirmPermissionRowItem
  ) -> some View {
    switch row {
    case .user(let details, _):
      self.userRow(for: details)

    case .group(let details, _):
      self.groupRow(for: details)
    }
  }

  private func userRow(
    for details: UserPermissionDetailsDSV
  ) -> some View {
    CommonListRow(
      contentAction: { await self.controller.openUserDetails(details.id) },
      content: {
        HStack(spacing: 8) {
          AsyncUserAvatarView(imageLoad: self.controller.avatar(for: details.id))
            .frame(width: 40, height: 40)

          ListRowTitleWithSubtitleView(
            title: DisplayableString(stringLiteral: details.rowTitle),
            subtitle: "\(details.username)"
          )
        }
        .opacity(details.isSuspended ? 0.6 : 1)
      },
      accessory: {
        self.permissionAccessory(current: details.permission)
      }
    )
    .padding(top: 8, bottom: 8)
    .frame(height: 64)
    // Keyed by the identity the operator sees, so a test can address a recipient without knowing its identifier.
    .accessibilityIdentifier("permissions.confirm.row.\(details.username)")
  }

  private func groupRow(
    for details: UserGroupPermissionDetailsDSV
  ) -> some View {
    CommonListRow(
      contentAction: { await self.controller.openGroupDetails(details.id) },
      content: {
        HStack(spacing: 8) {
          UserGroupAvatarView()
            .frame(width: 40, height: 40)

          Text("\(details.name)")
            .text(
              font: .inter(ofSize: 14, weight: .semibold),
              color: .passboltPrimaryText
            )
        }
      },
      accessory: {
        self.permissionAccessory(current: details.permission)
      }
    )
    .padding(top: 8, bottom: 8)
    .frame(height: 64)
    .accessibilityIdentifier("permissions.confirm.row.\(details.name)")
  }

  /// The read-only level badge and a disclosure chevron - every rendered row opens its recipient's details screen,
  /// where the level is adjusted.
  private func permissionAccessory(
    current: Permission
  ) -> some View {
    HStack(spacing: 4) {
      ResourcePermissionTypeCompactView(permission: current)
      DisclosureIndicatorImage()
    }
  }
}

extension UserPermissionDetailsDSV {

  fileprivate var rowTitle: String {
    let name: String = "\(self.firstName) \(self.lastName)"
    let suspendedMark: String =
      self.isSuspended
      ? " (\(DisplayableString.localized("resource.permission.details.user.suspended").string()))"
      : ""
    return name + suspendedMark
  }
}
