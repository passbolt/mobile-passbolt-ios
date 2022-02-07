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
import CommonModels

public final class TextSearchView: PlainView {

  public let textPublisher: AnyPublisher<String, Never>
  private let textField: TextField = .init()

  public init(
    leftAccesoryView: UIView? = nil,
    rightAccesoryView: UIView? = nil
  ) {
    let textSubject: PassthroughSubject<String, Never> = .init()
    self.textPublisher = textSubject.eraseToAnyPublisher()

    super.init()

    let searchIconView: ImageView = .init()
    mut(searchIconView) {
      .combined(
        .image(named: .search, from: .uiCommons),
        .tintColor(dynamic: .primaryText),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }

    let clearTextButton: ImageButton = .init()
    mut(clearTextButton) {
      .combined(
        .action { [unowned textField] in
          mut(textField) {
            .combined(
              .set(\.rightView, to: rightAccesoryView),
              .text("")
            )
          }
          textSubject.send("")
        },
        .tintColor(dynamic: .primaryText),
        .image(named: .close, from: .uiCommons),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }

    mut(self.textField) {
      .combined(
        .action(
          { [unowned self] textField in
            let isTextEntered: Bool = !(textField.text?.isEmpty ?? true)
            if isTextEntered {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: searchIconView as UIView?),
                  .set(\.rightView, to: clearTextButton)
                )
              }
            }
            else {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: searchIconView as UIView?),
                  .set(\.rightView, to: rightAccesoryView)
                )
              }
            }
            self.editingDidBegin()
          },
          for: .editingDidBegin
        ),
        .action(
          { textField in
            let isTextEntered: Bool = !(textField.text?.isEmpty ?? true)
            if isTextEntered {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: searchIconView as UIView?),
                  .set(\.rightView, to: clearTextButton)
                )
              }
            }
            else {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: leftAccesoryView ?? searchIconView),
                  .set(\.rightView, to: rightAccesoryView)
                )
              }
            }
            textSubject.send(textField.text ?? "")
          },
          for: .editingChanged
        ),
        .action(
          { [unowned self] textField in
            let isTextEntered: Bool = !(textField.text?.isEmpty ?? true)
            if isTextEntered {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: searchIconView as UIView?),
                  .set(\.rightView, to: clearTextButton)
                )
              }
            }
            else {
              mut(textField) {
                .combined(
                  .set(\.leftView, to: leftAccesoryView ?? searchIconView),
                  .set(\.rightView, to: rightAccesoryView)
                )
              }
            }
            self.editingDidEnd()
          },
          for: .editingDidEnd
        ),
        .textColor(dynamic: .primaryText),
        .tintColor(dynamic: .primaryText),
        .set(
          \.contentInsets,
          to: .init(
            top: 0,
            left: 12,
            bottom: 0,
            right: rightAccesoryView == nil ? 0 : 4
          )
        ),
        .set(\.leftView, to: leftAccesoryView ?? searchIconView),
        .set(\.leftViewMode, to: .always),
        .set(\.rightView, to: rightAccesoryView),
        .set(\.rightViewMode, to: .always),
        .set(\.clearButtonMode, to: .never),
        .set(\.returnKeyType, to: .search),
        .attributedPlaceholderString(
          .displayable(
            .localized(
              key:
                isInExtensionContext
                ? "autofill.extension.autofill.extension.resources.search.placeholder"
                : "resources.search.placeholder"
            ),
            font: .inter(ofSize: 14, weight: .regular),
            color: .secondaryText
          )
        ),
        .subview(of: self),
        .leadingAnchor(.equalTo, self.leadingAnchor, constant: 12),
        .topAnchor(.equalTo, self.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, self.bottomAnchor, constant: -12),
        .trailingAnchor(.equalTo, self.trailingAnchor, constant: -12)
      )
    }

    mut(self) {
      .combined(
        .border(dynamic: .divider, width: 1),
        .backgroundColor(dynamic: .backgroundAlternative),
        .cornerRadius(8, masksToBounds: true)
      )
    }
  }

  @available(*, unavailable)
  public required init() {
    unreachable(#function)
  }

  public func setText(_ text: String) {
    self.textField.text = text
  }

  private func editingDidBegin() {
    mut(self) {
      .border(dynamic: .primaryBlue, width: 1)
    }
  }

  private func editingDidEnd() {
    mut(self) {
      .border(dynamic: .divider, width: 1)
    }
  }

  public override func didMoveToSuperview() {
    super.didMoveToSuperview()
    guard  // auto fill available space when used in navigation bar
      let parentView: UIView = self.superview,
      parentView.superview is NavigationBar
    else { return }
    mut(self) {
      .widthAnchor(.equalTo, parentView.widthAnchor, constant: -28)
    }
  }
}
