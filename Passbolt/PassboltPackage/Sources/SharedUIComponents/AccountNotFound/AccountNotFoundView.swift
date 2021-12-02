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

import Accounts
import Combine
import UICommons

internal final class AccountNotFoundView: ScrolledStackView {

  internal let actionTapPublisher: AnyPublisher<Void, Never>

  private let accountNameLabel: Label = .init()
  private let accountUsernameLabel: Label = .init()
  private let accountDomainLabel: Label = .init()

  internal required init() {
    let actionTapSubject: PassthroughSubject<Void, Never> = .init()
    self.actionTapPublisher = actionTapSubject.eraseToAnyPublisher()

    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let imageView: ImageView = .init()
    mut(imageView) {
      .combined(
        .image(dynamic: .failureMark),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, imageView.heightAnchor),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .widthAnchor(.equalTo, widthAnchor, multiplier: 0.4, priority: .defaultHigh),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, topAnchor, constant: 42)
      )
    }

    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .text(localized: "account.not.found.title.label", inBundle: .sharedUIComponents),
        .font(.inter(ofSize: 24, weight: .regular)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(0),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, imageView.bottomAnchor, constant: 32)
      )
    }

    let messageLabel: Label = .init()
    mut(messageLabel) {
      .combined(
        .text(localized: "account.not.found.message.label", inBundle: .sharedUIComponents),
        .font(.inter(ofSize: 14, weight: .light)),
        .textColor(dynamic: .secondaryText),
        .numberOfLines(0),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16)
      )
    }

    let accountDetailsContainer: View = .init()
    mut(accountDetailsContainer) {
      .combined(
        .border(dynamic: .divider, width: 1),
        .cornerRadius(8),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, messageLabel.bottomAnchor, constant: 32)
      )
    }

    mut(accountNameLabel) {
      .combined(
        .font(.inter(ofSize: 20, weight: .regular)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(1),
        .subview(of: accountDetailsContainer),
        .centerXAnchor(.equalTo, accountDetailsContainer.centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, accountDetailsContainer.leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, accountDetailsContainer.trailingAnchor, constant: -16),
        .topAnchor(.equalTo, accountDetailsContainer.topAnchor, constant: 16)
      )
    }

    mut(accountUsernameLabel) {
      .combined(
        .font(.inter(ofSize: 14, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .textAlignment(.center),
        .numberOfLines(1),
        .subview(of: accountDetailsContainer),
        .centerXAnchor(.equalTo, accountDetailsContainer.centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, accountDetailsContainer.leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, accountDetailsContainer.trailingAnchor, constant: -16),
        .topAnchor(.equalTo, accountNameLabel.bottomAnchor, constant: 16)
      )
    }

    mut(accountDomainLabel) {
      .combined(
        .font(.inter(ofSize: 12, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .textAlignment(.center),
        .numberOfLines(1),
        .subview(of: accountDetailsContainer),
        .centerXAnchor(.equalTo, accountDetailsContainer.centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, accountDetailsContainer.leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, accountDetailsContainer.trailingAnchor, constant: -16),
        .topAnchor(.equalTo, accountUsernameLabel.bottomAnchor, constant: 12),
        .bottomAnchor(.equalTo, accountDetailsContainer.bottomAnchor, constant: -24)
      )
    }

    let actionButton: TextButton = .init()
    mut(actionButton) {
      .combined(
        .text(localized: "account.not.found.action.button.title", inBundle: .sharedUIComponents),
        .action(actionTapSubject.send),
        .subview(of: self),
        .primaryStyle(),
        .topAnchor(.greaterThanOrEqualTo, accountDetailsContainer.bottomAnchor, constant: -16),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
        .bottomAnchor(.equalTo, safeAreaLayoutGuide.bottomAnchor, constant: -16)
      )
    }
  }

  internal func update(from accountWithProfile: AccountWithProfile) {
    mut(accountNameLabel) {
      .text(accountWithProfile.label)
    }
    mut(accountUsernameLabel) {
      .text(accountWithProfile.username)
    }
    mut(accountDomainLabel) {
      .text(accountWithProfile.domain.rawValue)
    }
  }
}
