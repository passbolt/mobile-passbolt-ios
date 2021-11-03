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

import Combine
import Commons
import UIKit

public final class CheckedLabel: View {

  public var tapPublisher: AnyPublisher<Void, Never> { container.tapPublisher }

  private let container: Button = .init()
  private let imageView: ImageView = .init()
  private let label: Label = .init()

  public required init() {
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }

    mut(container) {
      .combined(
        .backgroundColor(dynamic: .background),
        .enabled(),
        .subview(of: self),
        .edges(equalTo: self)
      )
    }

    mut(imageView) {
      .combined(
        .contentMode(.scaleAspectFit),
        .userInteractionEnabled(false),
        .subview(of: container),
        .widthAnchor(.equalTo, heightAnchor),
        .leadingAnchor(.equalTo, leadingAnchor),
        .topAnchor(.equalTo, topAnchor, constant: 8),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -8)
      )
    }

    mut(label) {
      .combined(
        .userInteractionEnabled(false),
        .subview(of: container),
        .leadingAnchor(.equalTo, imageView.trailingAnchor, constant: 8),
        .trailingAnchor(.equalTo, trailingAnchor),
        .centerYAnchor(.equalTo, imageView.centerYAnchor)
      )
    }
  }

  public func update(checked: Bool) {
    mut(imageView) {
      .when(
        checked,
        then: .image(named: .checked, from: .uiCommons),
        else: .image(named: .unchecked, from: .uiCommons)
      )
    }
  }

  public func applyOn(label mutation: Mutation<Label>) {
    mutation.apply(on: label)
  }
}
