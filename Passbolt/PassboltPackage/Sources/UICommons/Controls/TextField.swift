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

import CommonModels
import UIKit

open class TextField: UITextField {

  public lazy var dynamicBackgroundColor: DynamicColor = .always(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public var dynamicTintColor: DynamicColor? {
    didSet {
      self.tintColor = dynamicTintColor?(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicTextColor: DynamicColor = .always(self.textColor) {
    didSet {
      self.textColor = dynamicTextColor(in: traitCollection.userInterfaceStyle)
    }
  }

  public var dynamicBorderColor: DynamicColor? = nil {
    didSet {
      self.layer.borderColor = dynamicBorderColor?(in: traitCollection.userInterfaceStyle).cgColor
    }
  }

  // Conflicts with `attributedPlaceholder` property, never use both at the same time.
  public var attributedPlaceholderString: AttributedString? {
    didSet {
      self.attributedPlaceholder = attributedPlaceholderString?
        .nsAttributedString(
          in: traitCollection.userInterfaceStyle
        )
    }
  }

  public var endEditingOnReturn: Bool = true

  public var contentInsets: UIEdgeInsets = .zero {
    didSet { setNeedsLayout() }
  }

  public required init() {
    super.init(frame: .zero)
    self.delegate = self
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
  }

  override open func textRect(forBounds bounds: CGRect) -> CGRect {
    super.textRect(forBounds: bounds.inset(by: contentInsets))
  }

  override open func editingRect(forBounds bounds: CGRect) -> CGRect {
    super.editingRect(forBounds: bounds.inset(by: contentInsets))
  }

  override open func rightViewRect(forBounds bounds: CGRect) -> CGRect {
    super.rightViewRect(forBounds: bounds.inset(by: contentInsets))
  }

  override open func leftViewRect(forBounds bounds: CGRect) -> CGRect {
    super.leftViewRect(forBounds: bounds.inset(by: contentInsets))
  }

  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }

  private func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.backgroundColor = dynamicBackgroundColor(in: interfaceStyle)
    self.layer.borderColor = dynamicBorderColor?(in: interfaceStyle).cgColor
    self.tintColor = dynamicTintColor?(in: interfaceStyle)
    self.textColor = dynamicTextColor(in: interfaceStyle)
    if let attributedPlaceholderString = attributedPlaceholderString?.nsAttributedString(in: interfaceStyle) {
      self.attributedPlaceholder = attributedPlaceholderString
    }
    else {
      /* NOP */
    }
  }
}

extension TextField: UITextFieldDelegate {

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if endEditingOnReturn {
      resignFirstResponder()
    }
    else {
      /* */
    }

    return false
  }
}
