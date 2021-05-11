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

import Combine
import UICommons

internal final class WelcomeScreenView: ScrolledStackView {
  internal var tapAccountPublisher: AnyPublisher<Void, Never> { accountButton.tapPublisher }
  internal var tapNoAccountPublisher: AnyPublisher<Void, Never> { noAccountButton.tapPublisher }
  
  private let logoImageView: ImageView = .init()
  private let accountsImageView: ImageView = .init()
  private let titleLabel: Label = .init()
  private let descriptionLabel: Label = .init()
  private let accountButton: TextButton = .init()
  private let noAccountButton: TextButton = .init()
    
  internal override func setup() {
    
    let logoContainer: View = Mutation
      .backgroundColor(dynamic: .background)
      .instantiate()
    
    mut(logoImageView) {
      .combined(
        .subview(of: logoContainer),
        .image(named: .appLogo),
        .contentMode(.scaleAspectFit),
        .topAnchor(.equalTo, logoContainer.topAnchor),
        .bottomAnchor(.equalTo, logoContainer.bottomAnchor),
        .centerXAnchor(.equalTo, logoContainer.centerXAnchor),
        .widthAnchor(.equalTo, constant: 118),
        .accessibilityIdentifier("welcome.app.logo.imageview")
      )
    }
    
    let accountsContainer: View = Mutation
      .backgroundColor(dynamic: .background)
      .instantiate()
    
    mut(accountsImageView) {
      .combined(
        .subview(of: accountsContainer),
        .image(named: .welcomeAccounts),
        .topAnchor(.equalTo, accountsContainer.topAnchor),
        .bottomAnchor(.equalTo, accountsContainer.bottomAnchor),
        .centerXAnchor(.equalTo, accountsContainer.centerXAnchor),
        .accessibilityIdentifier("welcome.accounts.imageview")
      )
    }
    
    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 24, weight: .semibold)),
        .textAlignment(.center),
        .text(localized: "welcome.title"),
        .accessibilityIdentifier("welcome.title.label")
      )
    }
    
    mut(descriptionLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .lineBreakMode(.byWordWrapping),
        .numberOfLines(0),
        .textColor(dynamic: .secondaryText),
        .text(localized: "welcome.description"),
        .accessibilityIdentifier("welcome.description.label")
      )
    }
     
    mut(accountButton) {
      .combined(
        .primaryStyle(),
        .text(localized: "welcome.connect.to.account"),
        .accessibilityIdentifier("welcome.connect.account.button")
      )
    }
    
    mut(noAccountButton) {
      .combined(
        .linkStyle(),
        .text(localized: "welcome.no.account"),
        .accessibilityIdentifier("welcome.no.account.button")
      )
    }
    
    mut(self) {
      .combined(
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 60, left: 16, bottom: 8, right: 16)),
        .append(logoContainer),
        .appendSpace(of: 56),
        .append(accountsContainer),
        .appendSpace(of: 56),
        .append(titleLabel),
        .appendSpace(of: 56),
        .append(descriptionLabel),
        .appendFiller(minSize: 20),
        .append(accountButton),
        .append(noAccountButton)
      )
    }
  }
}
