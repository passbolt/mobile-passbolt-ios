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

import AegithalosCocoa
import Combine

public final class ResultView: PlainView {

  public var buttonTapPublisher: AnyPublisher<Void, Never> { actionButton.tapPublisher }

  private lazy var imageView: ImageView = .init()
  private lazy var titleLabel: Label = .init()
  private lazy var messageLabel: Label = .init()
  private lazy var actionButton: TextButton = .init()

  override public func setup() {
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }

    mut(imageView) {
      .combined(
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, imageView.heightAnchor),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .widthAnchor(.equalTo, widthAnchor, multiplier: 0.4, priority: .defaultHigh),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .centerYAnchor(.equalTo, centerYAnchor, constant: -40)
      )
    }

    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 24, weight: .semibold)),
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

    mut(messageLabel) {
      .combined(
        .font(.inter(ofSize: 14, weight: .light)),
        .textColor(dynamic: .secondaryText),
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .subview(of: self),
        .centerXAnchor(.equalTo, centerXAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, leadingAnchor, constant: 16),
        .trailingAnchor(.lessThanOrEqualTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 32)
      )
    }

    mut(actionButton) {
      .combined(
        .subview(of: self),
        .primaryStyle(),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
        .bottomAnchor(.equalTo, safeAreaLayoutGuide.bottomAnchor, constant: -16)
      )
    }
  }

  public func applyOn(image mutation: Mutation<ImageView>) {
    mutation.apply(on: imageView)
  }

  public func applyOn(title mutation: Mutation<Label>) {
    mutation.apply(on: titleLabel)
  }

  public func applyOn(message mutation: Mutation<Label>) {
    mutation.apply(on: messageLabel)
  }

  public func applyOn(button mutation: Mutation<TextButton>) {
    mutation.apply(on: actionButton)
  }
}
