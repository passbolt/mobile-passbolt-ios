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

public final class LabeledSwitch: View {

  public var togglePublisher: AnyPublisher<Void, Never> { toggleSubject.eraseToAnyPublisher() }

  private let label: Label = .init()
  private let toggle: UISwitch = .init()

  private let toggleSubject: PassthroughSubject<Void, Never> = .init()

  public required init() {
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    mut(label) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .topAnchor(.equalTo, topAnchor, constant: 12),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -12),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText)
      )
    }

    mut(toggle) {
      .combined(
        .subview(of: self),
        .centerYAnchor(.equalTo, label.centerYAnchor),
        .leadingAnchor(.greaterThanOrEqualTo, label.trailingAnchor, constant: 8),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -4),
        .action { [weak self] _ in
          self?.toggleSubject.send()
        }
      )
    }
  }

  public func applyOn(label mutation: Mutation<Label>) {
    mutation.apply(on: label)
  }

  public func update(isOn: Bool) {
    mut(toggle) {
      .set(\.isOn, to: isOn)
    }
  }
}
