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

  override internal func setup() {

    let logoContainer: ContainerView = .init(
      contentView: logoImageView,
      mutation: .combined(
        .image(named: .passboltLogo, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .accessibilityIdentifier("welcome.app.logo.imageview")
      ),
      widthMultiplier: 0.4,
      heightMultiplier: 1
    )

    let accountsContainer: ContainerView = .init(
      contentView: accountsImageView,
      mutation: .combined(
        .image(named: .accountsSkeleton, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, accountsImageView.heightAnchor),
        .accessibilityIdentifier("welcome.accounts.imageview")
      ),
      widthMultiplier: 0.7,
      heightMultiplier: 1
    )

    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 24, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .text(displayable: .localized(key: "welcome.title")),
        .accessibilityIdentifier("welcome.title.label")
      )
    }

    mut(descriptionLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .lineBreakMode(.byWordWrapping),
        .textAlignment(.center),
        .numberOfLines(0),
        .textColor(dynamic: .secondaryText),
        .text(displayable: .localized(key: "welcome.description")),
        .accessibilityIdentifier("welcome.description.label")
      )
    }

    mut(accountButton) {
      .combined(
        .primaryStyle(),
        .text(displayable: .localized(key: "welcome.connect.to.account")),
        .accessibilityIdentifier("welcome.connect.account.button")
      )
    }

    mut(noAccountButton) {
      .combined(
        .linkStyle(),
        .text(displayable: .localized(key: "welcome.no.account")),
        .accessibilityIdentifier("welcome.no.account.button")
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 8, right: 16)),
        .append(logoContainer),
        .appendSpace(of: 24),
        .append(accountsContainer),
        .appendSpace(of: 24),
        .append(titleLabel),
        .appendSpace(of: 16),
        .append(descriptionLabel),
        .appendFiller(minSize: 16),
        .append(accountButton),
        .append(noAccountButton)
      )
    }
  }
}
