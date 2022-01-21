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

import UICommons

public final class ServerFingerprintView: ScrolledStackView {

  public var checkedTogglePublisher: AnyPublisher<Void, Never> { checkedLabel.tapPublisher }
  public var acceptTapPublisher: AnyPublisher<Void, Never> { acceptButton.tapPublisher }

  private let logoImageView: ImageView = .init()
  private let titleLabel: Label = .init()
  private let descriptionLabel: Label = .init()
  private let fingerprintLabel: Label = .init()
  private let checkedLabel: CheckedLabel = .init()
  private let acceptButton: TextButton = .init()

  @available(*, unavailable, message: "use init(fingerprint:")
  public required init() {
    unreachable(#function)
  }

  public init(fingerprint: String) {
    super.init()

    let logoContainer: ContainerView = .init(
      contentView: logoImageView,
      mutation: .combined(
        .image(dynamic: .passboltLogo),
        .contentMode(.scaleAspectFit)
      ),
      widthMultiplier: 0.4,
      heightMultiplier: 1
    )

    let container: View =
      Mutation
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (view: View) in
          view.layoutMargins = .init(top: 0, left: 40, bottom: 0, right: 40)
        }
      )
      .instantiate()

    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 24, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .text(
          displayable: .localized(key: "server.key.fingerprint.changed.title")
        ),
        .subview(of: container),
        .leadingAnchor(.equalTo, container.layoutMarginsGuide.leadingAnchor),
        .trailingAnchor(.equalTo, container.layoutMarginsGuide.trailingAnchor),
        .topAnchor(.equalTo, container.topAnchor)
      )
    }

    mut(descriptionLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .textColor(dynamic: .secondaryText),
        .textAlignment(.justified),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .text(
          displayable: .localized(key: "server.key.fingerprint.changed.description")
        ),
        .subview(of: container),
        .leadingAnchor(.equalTo, container.layoutMarginsGuide.leadingAnchor),
        .trailingAnchor(.equalTo, container.layoutMarginsGuide.trailingAnchor),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 16)
      )
    }

    mut(fingerprintLabel) {
      .combined(
        .font(.inconsolata(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .text(fingerprint),
        .subview(of: container),
        .leadingAnchor(.equalTo, container.layoutMarginsGuide.leadingAnchor),
        .trailingAnchor(.equalTo, container.layoutMarginsGuide.trailingAnchor),
        .topAnchor(.equalTo, descriptionLabel.bottomAnchor, constant: 64)
      )
    }

    mut(checkedLabel) {
      .combined(
        .subview(of: container),
        .centerXAnchor(.equalTo, container.layoutMarginsGuide.centerXAnchor),
        .topAnchor(.equalTo, fingerprintLabel.bottomAnchor, constant: 87),
        .bottomAnchor(.equalTo, container.bottomAnchor, constant: -8)
      )
    }

    checkedLabel.applyOn(
      label: .combined(
        .font(.inter(ofSize: 14)),
        .text(
          displayable: .localized(
            key: "server.key.fingerprint.accept.check"
          )
        ),
        .textColor(dynamic: .secondaryText)
      )
    )

    mut(acceptButton) {
      .combined(
        .primaryStyle(),
        .text(
          displayable: .localized(
            key: "server.key.fingerprint.accept.new.key"
          )
        )
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 16, right: 16)),
        .append(logoContainer),
        .appendSpace(of: 44),
        .append(container),
        .appendFiller(minSize: 20),
        .append(acceptButton)
      )
    }
  }

  public func update(checked: Bool) {
    checkedLabel.update(checked: checked)
    mut(acceptButton) {
      .when(
        checked,
        then: .enabled(),
        else: .disabled()
      )
    }
  }
}
