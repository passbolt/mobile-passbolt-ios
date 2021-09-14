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
import AegithalosCocoa

public final class OTPInput: UIControl, UIKeyInput {

  public var textPublisher: AnyPublisher<String, Never> {
    textSubject.eraseToAnyPublisher()
  }

  public var text: String {
    get { textSubject.value }
    set {
      if newValue.count > length {
        textSubject.value
        = String(
          newValue[
            newValue.startIndex
            ..< newValue.index(newValue.startIndex, offsetBy: length)
          ]
        )
      }
      else {
        textSubject.value = newValue
      }

      labels
        .enumerated()
        .forEach { idx, label in
          if idx < newValue.count {
            label.text
            = String(
              newValue[
                newValue.index(newValue.startIndex, offsetBy: idx)
                ... newValue.index(newValue.startIndex, offsetBy: idx)
              ]
            )
          } else {
            label.text = "_"
          }
        }
    }
  }
  public let length: Int
  public var hasText: Bool { !text.isEmpty }

  private let labelsContainer: StackView
  private let labels: Array<Label>
  private let textSubject: CurrentValueSubject<String, Never> = .init("")

  public required init(length: Int) {
    self.length = length
    let labelsContainer: StackView = .init()
    self.labelsContainer = labelsContainer
    self.labels = (0 ..< length)
      .map { _ in
        Mutation<Label>
          .combined(
            .font(.inter(ofSize: 36, weight: .semibold)),
            .textColor(dynamic: .primaryText),
            .textAlignment(.center),
            .text("_"),
            .widthAnchor(.equalTo, constant: 40),
            .userInteractionEnabled(false),
            .arrangedSubview(of: labelsContainer)
          )
          .instantiate()
      }
    super.init(frame: .zero)

    mut(labelsContainer) {
      .combined(
        .backgroundColor(.clear),
        .axis(.horizontal),
        .distribution(.equalSpacing),
        .userInteractionEnabled(false),
        .alignment(.fill),
        .subview(of: self),
        .edges(equalTo: self)
      )
    }

    addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  public func insertText(_ text: String) {
    guard self.text.count < length
    else { return }

    self.text.append(text)
  }

  public func deleteBackward() {
    _ = self.text.popLast()
  }

  public override var canBecomeFirstResponder: Bool {
    isEnabled
  }

  public var keyboardType: UIKeyboardType {
    get { .decimalPad }
    set { /* NOP */ }
  }

  @objc private func touchUpInside() {
    _ = becomeFirstResponder()
  }
}
