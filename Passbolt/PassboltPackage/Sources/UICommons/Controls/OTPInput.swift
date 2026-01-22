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

public final class OTPInput: UIControl, UIKeyInput {

  public var textPublisher: AnyPublisher<String, Never> {
    textSubject.eraseToAnyPublisher()
  }

  public var text: String {
    get { textSubject.value }
    set {
      if newValue.count > length {
        textSubject.value = String(
          newValue[
            newValue.startIndex ..< newValue.index(newValue.startIndex, offsetBy: length)
          ]
        )
      }
      else {
        textSubject.value = newValue
      }

      for (idx, label) in labels.enumerated() {
        if idx < newValue.count {
          label.text = String(
            newValue[
              newValue.index(newValue.startIndex, offsetBy: idx)
                ... newValue.index(newValue.startIndex, offsetBy: idx)
            ]
          )
        }
        else {
          label.text = "_"
        }
      }
    }
  }
  public let length: Int
  public var hasText: Bool { !text.isEmpty }

  private let labelsContainer: UIStackView
  private let labels: Array<UILabel>
  private let textSubject: CurrentValueSubject<String, Never> = .init("")

  public required init(length: Int) {
    self.length = length
    let container: UIStackView = .init()
    container.axis = .horizontal
    container.alignment = .fill
    container.backgroundColor = .clear
    container.isUserInteractionEnabled = false
    container.distribution = .equalSpacing
    container.translatesAutoresizingMaskIntoConstraints = false

    self.labelsContainer = container
    self.labels = (0 ..< length)
      .map { _ in
        let label: UILabel = .init()
        label.font = .inter(ofSize: 36, weight: .semibold)
        label.textColor = .passboltPrimaryText
        label.textAlignment = .center
        label.text = "_"
        label.isUserInteractionEnabled = false
        NSLayoutConstraint.activate([
          label.widthAnchor.constraint(equalToConstant: 40)
        ])
        return label
      }
    super.init(frame: .zero)

    self.addSubview(container)
    for label in labels {
      container.addArrangedSubview(label)
    }
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      container.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
    ])
    addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
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
    set { /* NOP */  }
  }

  public override func becomeFirstResponder() -> Bool {
    if super.becomeFirstResponder() {
      text = ""
      for label in labels {
        label.textColor = .passboltPrimaryText
      }
      return true
    }
    else {
      return false
    }
  }

  @objc private func touchUpInside() {
    _ = becomeFirstResponder()
  }
}
