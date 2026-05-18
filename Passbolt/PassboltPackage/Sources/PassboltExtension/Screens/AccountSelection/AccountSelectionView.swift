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
import SharedUIComponents

internal struct AccountSelectionView: ControlledView {

  internal let controller: AccountSelectionViewController

  internal init(controller: AccountSelectionViewController) {
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 0) {
      Image(named: .passboltLogo)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 118)
        .padding(.top, 90)

      with(\.mode) { mode in
        Text(displayable: mode.title)
          .titleStyle()
          .padding(.top, 94)

        Text(displayable: mode.subTitle)
          .infoStyle()
          .padding(.top, 16)
      }

      ScrollView {
        VStack {
          with(\.rows) { rows in
            ForEach(Array(rows.enumerated()), id: \.1.self) { index, row in
              switch row {
              case .account(let account):
                AsyncButton(
                  action: {
                    try await self.controller.selectAccount(account.account)
                  },
                  label: {
                    AccountSelectionRow(account: account)
                      .padding(.horizontal, 16)
                  }
                )
              case .addAccount:
                EmptyView()  // not supported yet
              }
              if index < rows.count - 1 {
                Divider()
                  .foregroundStyle(Color.passboltDivider)
                  .frame(height: 2)
                  .padding(.horizontal, 8)
                  .padding(.bottom, 4)
              }
            }
          }
        }
        .padding(.vertical, 16)
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.passboltDivider, lineWidth: 1)
        }
      }
      .padding(.top, 40)
    }
    .padding(.horizontal, 16)
    .backgroundColor(.passboltBackground)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        with(\.mode) { mode in
          if mode == .signIn {
            IconButton(
              iconName: .close,
              action: { self.controller.closeExtension() }
            )
          }
        }
      }
    }
  }
}

extension AccountSelectionViewController.Mode {

  fileprivate var title: DisplayableString {
    switch self {
    case .signIn:
      return "autofill.extension.account.selection.switch.account.title"
    case .switchAccount:
      return "autofill.extension.account.selection.sign.in.title"
    }
  }

  fileprivate var subTitle: DisplayableString {
    switch self {
    case .signIn:
      return "autofill.extension.account.selection.switch.account.subtitle"
    case .switchAccount:
      return "autofill.extension.account.selection.sign.in.subtitle"
    }
  }
}

private struct AccountSelectionRow: View {
  @State private var loadedImage: Image?
  private let account: AccountSelectionCellItem

  init(account: AccountSelectionCellItem) {
    self.account = account
  }

  var body: some View {
    HStack(spacing: 0) {
      (loadedImage ?? Image(named: .person))
        .resizable()
        .aspectRatio(contentMode: .fill)
        .cornerRadius(20)
        .tint(Color.passboltIcon)
        .frame(width: 40, height: 40)
        .overlay {
          Circle()
            .stroke(Color.passboltDivider, lineWidth: 1)
        }
        .task { @MainActor in
          if case .none = loadedImage, let data: Data = await account.imageLoad?() {
            loadedImage = Image(data: data) ?? Image(named: .person)
          }
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(account.title)
          .font(.inter(ofSize: 14, weight: .semibold))
          .foregroundColor(.passboltPrimaryText)
          .lineLimit(1)

        Text(account.subtitle)
          .font(.inter(ofSize: 12))
          .foregroundColor(.passboltSecondaryText)
          .lineLimit(1)
      }
      .padding(.leading, 12)
      Spacer()
    }
  }
}

#if DEBUG

#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        AccountSelectionView.self,
        with: .signIn
      )
    }
}
#endif
