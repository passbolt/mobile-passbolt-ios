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

  internal init(controller: Controller) {
    self.controller = controller
  }

  internal var body: some View {
    withAlert(
      \.alert,
      content: { content }
    )
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        whenFalse(\.isSignIn) {
          BackButton(action: self.controller.backButtonTapped)
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        IconButton(iconName: .help, action: self.controller.openHelp)
      }
    }
    .navigationBarBackButtonHidden()
    .overlay(alignment: .bottom) {
      with(\.mode) { mode in
        Group {
          switch mode {
          case .selection:
            SecondaryButton(
              title: "account.selection.remove.account.button.title",
              iconName: .trash,
              action: self.controller.toggleMode
            )
            .accessibilityIdentifier("account.selection.done.button")

          case .removal:
            PrimaryButton(
              title: .localized(key: .done),
              action: self.controller.toggleMode
            )
          }
        }
        .background(Color.passboltBackground)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
      }
    }
    .tabbarHidden()
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 0) {
      Image(named: .passboltLogo)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 118)
        .padding(.top, 50)
        .accessibilityIdentifier("account.selection.app.logo.imageview")

      with(\.mode) { mode in
        with(\.isSignIn) { isSignIn in
          if isSignIn {
            Text(displayable: mode.title)
              .titleStyle()
              .padding(.top, 94)
              .accessibilityIdentifier("account.selection.title")
          }
          else {
            Rectangle()
              .foregroundStyle(Color.clear)
              .frame(height: 94)
          }
        }

        Text(displayable: mode.subTitle)
          .infoStyle()
          .padding(.top, 16)
      }

      ScrollView {
        VStack {
          with(\.accounts) { accounts in
            ForEach(Array(accounts.enumerated()), id: \.1.self) { index, account in
              AsyncButton(
                action: {
                  try await self.controller.selectAccount(account.account)
                },
                label: {
                  with(\.isRemovalMode) { isRemovalMode in
                    AccountSelectionRow(
                      account: account,
                      onRemoveTap: isRemovalMode
                        ? { @Sendable in
                          await self.controller.removeAccount(account.account)
                        }
                        : .none
                    )
                    .padding(.horizontal, 16)
                  }
                }
              )

              if index < accounts.count - 1 {
                divider
              }
            }
          }
          whenFalse(\.isRemovalMode) {
            divider

            AsyncButton(
              action: self.controller.addAccount,
              label: {
                HStack(spacing: 20) {
                  Image(named: .plus)
                    .tint(Color.passboltIconAlternative)
                    .frame(width: 20, height: 20)
                  Text(displayable: "account.selection.add.account.footer.title")
                    .font(.inter(ofSize: 14, weight: .semibold))
                    .foregroundColor(.passboltPrimaryText)
                  Spacer()
                }
                .padding(.leading, 28)
                .padding(.vertical, 8)
              }
            )
          }
        }
        .accessibilityIdentifier("account.selection.collectionview")
        .padding(.vertical, 16)
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.passboltDivider, lineWidth: 1)
        }
      }
      .padding(.top, 40)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 60)
    .backgroundColor(.passboltBackground)
    Spacer()
  }

  private var divider: some View {
    Divider()
      .foregroundStyle(Color.passboltDivider)
      .frame(height: 2)
      .padding(.horizontal, 8)
      .padding(.bottom, 4)
  }
}

extension AccountSelectionViewController.Mode {

  fileprivate var title: DisplayableString {
    switch self {
    case .selection:
      return "account.selection.title"
    case .removal:
      return "account.selection.remove.account.title"
    }
  }

  fileprivate var subTitle: DisplayableString {
    switch self {
    case .selection:
      return "account.selection.subtitle"
    case .removal:
      return "account.selection.remove.account.subtitle"
    }
  }
}

private struct AccountSelectionRow: View {
  @State private var currentImage: Image
  private let account: AccountSelectionCellItem
  private let onRemoveTap: (@MainActor @Sendable () async -> Void)?

  init(account: AccountSelectionCellItem, onRemoveTap: (@MainActor @Sendable () async -> Void)?) {
    self.account = account
    self.onRemoveTap = onRemoveTap
    self._currentImage = State(initialValue: Image(named: .person))
  }

  var body: some View {
    HStack(spacing: 0) {
      currentImage
        .resizable()
        .aspectRatio(contentMode: .fill)
        .cornerRadius(20)
        .tint(Color.passboltIcon)
        .frame(width: 40, height: 40)
        .overlay {
          Circle()
            .stroke(Color.passboltDivider, lineWidth: 1)
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
      if let onRemoveTap {
        IconButton(
          iconName: .trash,
          action: { await onRemoveTap() }
        )
        .accessibilityIdentifier("account.selection.remove.button")
      }
    }
    .onReceive(account.imagePublisher ?? Just(nil).eraseToAnyPublisher()) { @MainActor data in
      currentImage = data.flatMap { Image.init(data: $0) } ?? Image(named: .person)
    }
  }
}

#if DEBUG

#Preview {
  createPreview(
    AccountSelectionView.self,
    with: .init(
      isSignIn: true
    )
  )
  .wrapInNavigationStack()
}
#endif
