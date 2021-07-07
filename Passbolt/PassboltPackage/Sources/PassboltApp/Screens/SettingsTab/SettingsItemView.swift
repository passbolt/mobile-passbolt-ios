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

internal final class SettingsItemView: Button {

  private let icon: ImageView = .init()
  private let label: Label = .init()
  private let accessoryContainer: View = .init()

  internal required init() {
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let container: ContainerView = .init(
      contentView: icon,
      mutation: .combined(
        .tintColor(dynamic: .iconAlternative),
        .contentMode(.scaleAspectFit)
      )
    )

    mut(container) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 18),
        .topAnchor(.equalTo, topAnchor, constant: 14),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -14),
        .widthAnchor(.equalTo, constant: 24),
        .heightAnchor(.equalTo, constant: 24)
      )
    }

    mut(label) {
      .combined(
        .textColor(dynamic: .primaryText),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .subview(of: self),
        .centerYAnchor(.equalTo, container.centerYAnchor),
        .leadingAnchor(.equalTo, container.trailingAnchor, constant: 14)
      )
    }

    mut(accessoryContainer) {
      .combined(
        .backgroundColor(dynamic: .background),
        .subview(of: self),
        .leadingAnchor(.equalTo, label.trailingAnchor, constant: 14),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, topAnchor),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }
  }

  internal func applyOn(icon mutation: Mutation<ImageView>) {
    mutation.apply(on: icon)
  }

  internal func applyOn(label mutation: Mutation<Label>) {
    mutation.apply(on: label)
  }

  internal func add(accessory: UIView, with insets: UIEdgeInsets = .zero) {
    accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
    accessoryContainer.addSubview(accessory)

    accessory.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      accessory.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor, constant: insets.left),
      accessory.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor, constant: -insets.right),
      accessory.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor)
    ])
  }

  internal func addDisclosureIndicator() {
    accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
    
    Mutation<ImageView>
      .combined(
        .subview(of: accessoryContainer),
        .edges(
          equalTo: accessoryContainer,
          insets: .init(top: -18, left: -18, bottom: -18, right: -18),
          usingSafeArea: false
        ),
        .contentMode(.scaleAspectFit),
        .image(named: .disclosureIndicator, from: .uiCommons),
        .tintColor(dynamic: .icon),
        .backgroundColor(dynamic: .background)
      )
      .instantiate()
  }
}
