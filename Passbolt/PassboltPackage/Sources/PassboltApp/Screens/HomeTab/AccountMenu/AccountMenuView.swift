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
import AegithalosCocoa
import UICommons

internal final class AccountMenuView: PlainView {

  internal var signOutTapPublisher: AnyPublisher<Void, Never>
  internal var accountDetailsTapPublisher: AnyPublisher<Void, Never>
  internal var accountSwitchTapPublisher: AnyPublisher<Account, Never> {
    accountSwitchTapSubject.eraseToAnyPublisher()
  }
  private let accountSwitchTapSubject: PassthroughSubject<Account, Never> = .init()
  internal var manageAccountsTapPublisher: AnyPublisher<Void, Never>

  private let currentAcountWithProfile: AccountWithProfile
  private let accountsList: ScrolledStackView = .init()
  private let manageAccountsButton: ImageButton = .init()
  private let cancellables: Cancellables = .init()
  private var accountListCancellables: Cancellables = .init()

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable(#function)
  }

  @available(*, unavailable)
  internal required init() {
    unreachable(#function)
  }

  internal init(
    currentAcountWithProfile: AccountWithProfile,
    currentAcountAvatarImagePublisher: AnyPublisher<UIImage?, Never>
  ) {
    self.currentAcountWithProfile = currentAcountWithProfile

    let signOutButton: PlainButton = .init()
    self.signOutTapPublisher = signOutButton.tapPublisher

    let accountDetailsButton: PlainButton = .init()
    self.accountDetailsTapPublisher = accountDetailsButton.tapPublisher

    self.manageAccountsTapPublisher = manageAccountsButton.tapPublisher

    super.init()

    let accountAvatarImageView: ImageView = .init()
    mut(accountAvatarImageView) {
      .combined(
        .image(
          named: .person,
          from: .uiCommons
        ),
        .cornerRadius(20, masksToBounds: true),
        .border(dynamic: .divider),
        .tintColor(dynamic: .icon),
        .subview(of: self),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .topAnchor(.equalTo, topAnchor, constant: 16)
      )
    }
    mut(PlainView()) {
      .combined(
        .backgroundColor(dynamic: .secondaryGreen),
        .border(dynamic: .background, width: 2),
        .cornerRadius(6, masksToBounds: true),
        .subview(of: self),
        .topAnchor(.equalTo, accountAvatarImageView.topAnchor),
        .trailingAnchor(.equalTo, accountAvatarImageView.trailingAnchor),
        .widthAnchor(.equalTo, constant: 12),
        .heightAnchor(.equalTo, constant: 12)
      )
    }
    currentAcountAvatarImagePublisher
      .receive(on: RunLoop.main)
      .sink { image in
        mut(accountAvatarImageView) {
          .whenSome(
            image,
            then: { image in
              .image(image)
            },
            else: .image(
              named: .person,
              from: .uiCommons
            )
          )
        }
      }
      .store(in: cancellables)

    let accountLabelLabel: Label = .init()
    mut(accountLabelLabel) {
      .combined(
        .numberOfLines(1),
        .text(currentAcountWithProfile.label),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .lineBreakMode(.byTruncatingMiddle)
      )
    }
    let accountEmailLabel: Label = .init()
    mut(accountEmailLabel) {
      .combined(
        .numberOfLines(1),
        .text(currentAcountWithProfile.username),
        .font(.inter(ofSize: 12, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .lineBreakMode(.byTruncatingMiddle)
      )
    }

    let accountLabels: StackView = .init()
    mut(accountLabels) {
      .combined(
        .axis(.vertical),
        .alignment(.leading),
        .distribution(.equalSpacing),
        .spacing(4),
        .arrangedSubview(accountLabelLabel, accountEmailLabel),
        .subview(of: self),
        .centerYAnchor(.equalTo, accountAvatarImageView.centerYAnchor),
        .leadingAnchor(.equalTo, accountAvatarImageView.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    mut(accountDetailsButton) {
      .combined(
        .cornerRadius(4, masksToBounds: true),
        .backgroundColor(dynamic: .divider),
        .subview(of: self),
        .heightAnchor(.equalTo, constant: 40),
        .topAnchor(.equalTo, accountAvatarImageView.bottomAnchor, constant: 16),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16)
      )
    }

    let accountDetailsButtonContent: PlainView = .init()
    mut(accountDetailsButtonContent) {
      .combined(
        .userInteractionEnabled(false),
        .backgroundColor(.clear),
        .subview(of: accountDetailsButton),
        .centerXAnchor(.equalTo, accountDetailsButton.centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, accountDetailsButton.leadingAnchor, constant: 4),
        .trailingAnchor(.lessThanOrEqualTo, accountDetailsButton.trailingAnchor, constant: -4),
        .topAnchor(.equalTo, accountDetailsButton.topAnchor, constant: 4),
        .bottomAnchor(.equalTo, accountDetailsButton.bottomAnchor, constant: -4)
      )
    }

    let accountDetailsButtonIcon: ImageView = .init()
    mut(accountDetailsButtonIcon) {
      .combined(
        .image(named: "User", from: .uiCommons),
        .tintColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: accountDetailsButtonContent),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20),
        .leadingAnchor(.equalTo, accountDetailsButtonContent.leadingAnchor),
        .centerYAnchor(.equalTo, accountDetailsButtonContent.centerYAnchor)
      )
    }
    let accountDetailsButtonLabel: Label = .init()
    mut(accountDetailsButtonLabel) {
      .combined(
        .text(displayable: .localized(key: "account.menu.account.details.button.title")),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: accountDetailsButtonContent),
        .leadingAnchor(.equalTo, accountDetailsButtonIcon.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, accountDetailsButtonContent.trailingAnchor, constant: -16),
        .topAnchor(.equalTo, accountDetailsButtonContent.topAnchor),
        .bottomAnchor(.equalTo, accountDetailsButtonContent.bottomAnchor)
      )
    }

    mut(signOutButton) {
      .combined(
        .cornerRadius(4, masksToBounds: true),
        .backgroundColor(dynamic: .divider),
        .subview(of: self),
        .widthAnchor(.equalTo, accountDetailsButton.widthAnchor),
        .heightAnchor(.equalTo, constant: 40),
        .centerYAnchor(.equalTo, accountDetailsButton.centerYAnchor),
        .leadingAnchor(.equalTo, accountDetailsButton.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    let signOutButtonContent: PlainView = .init()
    mut(signOutButtonContent) {
      .combined(
        .userInteractionEnabled(false),
        .backgroundColor(.clear),
        .subview(of: signOutButton),
        .centerXAnchor(.equalTo, signOutButton.centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, signOutButton.leadingAnchor, constant: 4),
        .trailingAnchor(.lessThanOrEqualTo, signOutButton.trailingAnchor, constant: -4),
        .topAnchor(.equalTo, signOutButton.topAnchor, constant: 4),
        .bottomAnchor(.equalTo, signOutButton.bottomAnchor, constant: -4)
      )
    }

    let signOutButtonIcon: ImageView = .init()
    mut(signOutButtonIcon) {
      .combined(
        .image(named: "SignOut", from: .uiCommons),
        .tintColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: signOutButtonContent),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20),
        .leadingAnchor(.equalTo, signOutButtonContent.leadingAnchor),
        .centerYAnchor(.equalTo, signOutButtonContent.centerYAnchor)
      )
    }
    let signOutButtonLabel: Label = .init()
    mut(signOutButtonLabel) {
      .combined(
        .text(displayable: .localized(key: "account.menu.sign.out.button.title")),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: signOutButtonContent),
        .leadingAnchor(.equalTo, signOutButtonIcon.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, signOutButtonContent.trailingAnchor, constant: -16),
        .topAnchor(.equalTo, signOutButtonContent.topAnchor),
        .bottomAnchor(.equalTo, signOutButtonContent.bottomAnchor)
      )
    }

    mut(accountsList) {
      .combined(
        .backgroundColor(.clear),
        .subview(of: self),
        .topAnchor(.equalTo, signOutButton.bottomAnchor, constant: 16),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16)
      )
    }

    mut(manageAccountsButton) {
      .combined(
        .backgroundColor(.clear),
        .subview(of: self),
        .heightAnchor(.equalTo, constant: 40),
        .topAnchor(.equalTo, accountsList.bottomAnchor, constant: 12),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
        .bottomAnchor(.equalTo, safeAreaLayoutGuide.bottomAnchor, constant: -8)
      )
    }

    let manageAccountsButtonIcon: ImageView = .init()
    mut(manageAccountsButtonIcon) {
      .combined(
        .image(named: "Users", from: .uiCommons),
        .tintColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: manageAccountsButton),
        .heightAnchor(.equalTo, manageAccountsButtonIcon.widthAnchor),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20),
        .leadingAnchor(.equalTo, manageAccountsButton.leadingAnchor, constant: 8),
        .centerYAnchor(.equalTo, manageAccountsButton.centerYAnchor)
      )
    }
    let manageAccountsButtonLabel: Label = .init()
    mut(manageAccountsButtonLabel) {
      .combined(
        .text(displayable: .localized(key: "account.menu.manage.accounts.button.title")),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .userInteractionEnabled(false),
        .subview(of: manageAccountsButton),
        .leadingAnchor(.equalTo, manageAccountsButtonIcon.trailingAnchor, constant: 24),
        .trailingAnchor(.equalTo, manageAccountsButton.trailingAnchor, constant: -16),
        .centerYAnchor(.equalTo, manageAccountsButton.centerYAnchor)
      )
    }
  }

  internal func updateAccountsList(
    accounts: Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<UIImage?, Never>)>
  ) {
    accountListCancellables = .init()
    accountsList.removeAllArrangedSubviews()
    mut(accountsList) {
      .combined(
        .append(
          Mutation<PlainView>
            .combined(
              .backgroundColor(dynamic: .divider),
              .heightAnchor(.equalTo, constant: 1)
            )
            .instantiate()
        ),
        .forEach(
          in: accounts,
          { [unowned self] account in
            .combined(
              .append(
                self.profileCell(
                  accountWithProfile: account.accountWithProfile,
                  avatarImagePublisher: account.avatarImagePublisher
                )
              ),
              .append(
                Mutation<PlainView>
                  .combined(
                    .backgroundColor(dynamic: .divider),
                    .heightAnchor(.equalTo, constant: 1)
                  )
                  .instantiate()
              )
            )
          }
        )
      )
    }
  }

  private func profileCell(
    accountWithProfile: AccountWithProfile,
    avatarImagePublisher: AnyPublisher<UIImage?, Never>
  ) -> PlainButton {
    let container: PlainButton = .init()
    mut(container) {
      .combined(
        .backgroundColor(.clear),
        .action { [weak self] in
          self?.accountSwitchTapSubject.send(accountWithProfile.account)
        }
      )
    }

    let accountAvatarImageView: ImageView = .init()
    mut(accountAvatarImageView) {
      .combined(
        .image(
          named: .person,
          from: .uiCommons
        ),
        .cornerRadius(20, masksToBounds: true),
        .border(dynamic: .divider),
        .tintColor(dynamic: .icon),
        .userInteractionEnabled(false),
        .subview(of: container),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40),
        .leadingAnchor(.equalTo, container.leadingAnchor),
        .topAnchor(.equalTo, container.topAnchor, constant: 16)
      )
    }
    avatarImagePublisher
      .receive(on: RunLoop.main)
      .sink { image in
        mut(accountAvatarImageView) {
          .whenSome(
            image,
            then: { image in
              .image(image)
            },
            else: .image(
              named: .person,
              from: .uiCommons
            )
          )
        }
      }
      .store(in: accountListCancellables)

    let accountLabelLabel: Label = .init()
    mut(accountLabelLabel) {
      .combined(
        .userInteractionEnabled(false),
        .numberOfLines(1),
        .text(accountWithProfile.label),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .lineBreakMode(.byTruncatingMiddle)
      )
    }
    let accountEmailLabel: Label = .init()
    mut(accountEmailLabel) {
      .combined(
        .userInteractionEnabled(false),
        .numberOfLines(1),
        .text(accountWithProfile.username),
        .font(.inter(ofSize: 12, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .lineBreakMode(.byTruncatingMiddle)
      )
    }

    let accountLabels: StackView = .init()
    mut(accountLabels) {
      .combined(
        .userInteractionEnabled(false),
        .axis(.vertical),
        .alignment(.leading),
        .distribution(.equalSpacing),
        .spacing(4),
        .arrangedSubview(accountLabelLabel, accountEmailLabel),
        .subview(of: container),
        .centerYAnchor(.equalTo, accountAvatarImageView.centerYAnchor),
        .leadingAnchor(.equalTo, accountAvatarImageView.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, container.trailingAnchor),
        .bottomAnchor(.equalTo, container.bottomAnchor, constant: -16)
      )
    }

    return container
  }
}
