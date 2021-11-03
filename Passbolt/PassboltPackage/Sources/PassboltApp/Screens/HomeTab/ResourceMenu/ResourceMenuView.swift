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

internal final class ResourceMenuView: View {

  internal var closeButtonTapPublisher: AnyPublisher<Void, Never> { button.tapPublisher }
  internal var itemTappedPublisher: AnyPublisher<ResourceMenuController.Action, Never> {
    itemTappedSubject.eraseToAnyPublisher()
  }

  private let itemTappedSubject: PassthroughSubject<ResourceMenuController.Action, Never> = .init()

  private let titleLabel: Label = .init()
  private let button: ImageButton = .init()
  private let stack: ScrolledStackView = .init()

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  internal required init() {
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .subview(titleLabel, button, stack)
      )
    }

    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 20, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .leadingAnchor(.equalTo, leadingAnchor, constant: 16),
        .trailingAnchor(.equalTo, button.leadingAnchor, constant: -8),
        .topAnchor(.equalTo, topAnchor, constant: 16),
        .bottomAnchor(.equalTo, stack.topAnchor)
      )
    }

    mut(button) {
      .combined(
        .image(named: .close, from: .uiCommons),
        .tintColor(dynamic: .iconAlternative),
        .trailingAnchor(.equalTo, trailingAnchor, constant: -16),
        .topAnchor(.equalTo, topAnchor, constant: 16),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20)
      )
    }

    mut(stack) {
      .combined(
        .isLayoutMarginsRelativeArrangement(true),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .bottomAnchor(.equalTo, bottomAnchor),
        .contentInset(.init(top: 16, left: 16, bottom: 16, right: 16))
      )
    }
  }

  internal func update(title: String) {
    mut(titleLabel) {
      .text(title)
    }
  }

  internal func update(operations: Array<ResourceMenuController.Action>) {
    stack.removeAllArrangedSubviews()

    let menuItems: Array<ResourceMenuItemView> = operations.map { operation in
      let item: ResourceMenuItemView = .init(operation: operation)

      mut(item) {
        .action { [weak self] in self?.itemTappedSubject.send(item.operation) }
      }

      switch item.operation {
      case .openURL:
        mut(item.imageView) {
          .image(named: .open, from: .uiCommons)
        }

        mut(item.titleLabel) {
          .text(localized: "resource.menu.item.open.url")
        }

      case .copyURL:
        mut(item.imageView) {
          .image(named: .copy, from: .uiCommons)
        }

        mut(item.titleLabel) {
          .text(localized: "resource.menu.item.copy.url")
        }

      case .copyPassword:
        mut(item.imageView) {
          .image(named: .key, from: .uiCommons)
        }

        mut(item.titleLabel) {
          .text(localized: "resource.menu.item.copy.password")
        }

      case .copyUsername:
        mut(item.imageView) {
          .image(named: .user, from: .uiCommons)
        }

        mut(item.titleLabel) {
          .text(localized: "resource.menu.item.copy.username")
        }

      case .copyDescription:
        mut(item.imageView) {
          .image(named: .description, from: .uiCommons)
        }

        mut(item.titleLabel) {
          .text(localized: "resource.menu.item.copy.description")
        }

      case .delete:
        mut(item.imageView) {
          .combined(
            .image(named: .trash, from: .uiCommons),
            .tintColor(dynamic: .secondaryRed)
          )
        }

        mut(item.titleLabel) {
          .combined(
            .text(localized: "resource.menu.item.delete.password"),
            .textColor(dynamic: .secondaryRed)
          )
        }
      }

      return item
    }

    mut(stack) {
      .forEach(in: menuItems) { item in
        .append(item)
      }
    }
  }
}

internal final class ResourceMenuItemView: Button {

  internal let operation: ResourceMenuController.Action

  fileprivate let imageView: ImageView = .init()
  fileprivate let titleLabel: Label = .init()

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  @available(*, unavailable, message: "Use init(operation:)")
  required init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  internal init(operation: ResourceMenuController.Action) {
    self.operation = operation
    super.init()

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .subview(imageView, titleLabel)
      )
    }

    mut(imageView) {
      .combined(
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, titleLabel.leadingAnchor, constant: -16),
        .topAnchor(.equalTo, topAnchor, constant: 18),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -18),
        .widthAnchor(.equalTo, constant: 18),
        .heightAnchor(.equalTo, constant: 18),
        .contentMode(.scaleAspectFit),
        .tintColor(dynamic: .iconAlternative)
      )
    }

    mut(titleLabel) {
      .combined(
        .trailingAnchor(.equalTo, trailingAnchor),
        .centerYAnchor(.equalTo, imageView.centerYAnchor),
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText)
      )
    }
  }
}
