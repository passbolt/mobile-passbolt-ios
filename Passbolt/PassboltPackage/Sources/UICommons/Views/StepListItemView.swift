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

public final class StepListItemView: View {

  private let iconContainer: View = .init()
  private let label: Label = .init()

  public required init() {
    super.init()

    mut(self) {
      .backgroundColor(.clear)
    }

    mut(iconContainer) {
      .combined(
        .backgroundColor(.clear),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .centerYAnchor(.equalTo, centerYAnchor)
      )
    }

    mut(label) {
      .combined(
        .backgroundColor(.clear),
        .textColor(dynamic: .secondaryText),
        .font(.inter(ofSize: 14, weight: .regular)),
        .numberOfLines(0),
        .subview(of: self),
        .leadingAnchor(.equalTo, iconContainer.trailingAnchor, constant: 12),
        .topAnchor(.equalTo, topAnchor),
        .bottomAnchor(.equalTo, bottomAnchor),
        .trailingAnchor(.equalTo, trailingAnchor)
      )
    }
  }

  public func apply(onLabel mutation: Mutation<Label>) {
    mutation.apply(on: label)
  }

  public func setIconView(_ view: UIView) {
    mut(view) {
      .combined(
        .subview(of: iconContainer),
        .edges(equalTo: iconContainer, usingSafeArea: false)
      )
    }
  }
}

extension Mutation where Subject: StepListItemView {

  public static func label(mutatation: Mutation<Label>) -> Self {
    .custom { (subject: Subject) in
      subject.apply(onLabel: mutatation)
    }
  }

  public static func iconView(_ view: UIView) -> Self {
    .custom { (subject: Subject) in
      subject.setIconView(view)
    }
  }
}
