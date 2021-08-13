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

public class TextButton: Button {

  public lazy var dynamicTextColor: DynamicColor = .always(self.textColor) {
    didSet {
      self.textColor = dynamicTextColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicPressedTextColor: DynamicColor = .always(self.pressedTextColor) {
    didSet {
      self.pressedTextColor = dynamicPressedTextColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicDisabledTextColor: DynamicColor = .always(self.disabledTextColor) {
    didSet {
      self.disabledTextColor = dynamicDisabledTextColor(in: traitCollection.userInterfaceStyle)
    }
  }

  private let label: Label = .init()

  public required init() {
    super.init()
    setup()
  }

  override internal func pressed() {
    super.pressed()
    label.textColor = pressedTextColor
  }

  override internal func released() {
    super.released()
    label.textColor = textColor
  }

  override internal func enabled() {
    super.enabled()
    label.textColor = textColor
  }

  override internal func disabled() {
    super.disabled()
    label.textColor = disabledTextColor
  }

  public var text: String {
    get { label.text ?? "" }
    set { label.text = newValue }
  }

  public var textColor: UIColor = .black {
    didSet {
      guard !isPressed, isEnabled else { return }
      label.textColor = textColor
    }
  }

  public lazy var pressedTextColor: UIColor = textColor {
    didSet {
      guard isPressed, isEnabled else { return }
      label.textColor = pressedTextColor
    }
  }

  public lazy var disabledTextColor: UIColor = textColor {
    didSet {
      guard !isEnabled else { return }
      label.textColor = disabledTextColor
    }
  }

  public var font: UIFont {
    get { label.font }
    set { label.font = newValue }
  }

  public var textAlignment: NSTextAlignment {
    get { label.textAlignment }
    set { label.textAlignment = newValue }
  }

  public var textLineBreakMode: NSLineBreakMode {
    get { label.lineBreakMode }
    set { label.lineBreakMode = newValue }
  }

  public var textNumberOfLines: Int {
    get { label.numberOfLines }
    set { label.numberOfLines = newValue }
  }

  public var textInsets: NSDirectionalEdgeInsets {
    get {
      NSDirectionalEdgeInsets(
        top: labelTopConstraint?.constant ?? 0,
        leading: labelLeadingConstraint?.constant ?? 0,
        bottom: labelBottomConstraint?.constant ?? 0,
        trailing: labelTrailingConstraint?.constant ?? 0
      )
    }
    set {
      labelTopConstraint?.constant = newValue.top
      labelLeadingConstraint?.constant = newValue.leading
      labelBottomConstraint?.constant = newValue.bottom
      labelTrailingConstraint?.constant = newValue.trailing
    }
  }

  override internal func updateColors() {
    super.updateColors()
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.textColor = dynamicTextColor(in: interfaceStyle)
    self.pressedTextColor = dynamicPressedTextColor(in: interfaceStyle)
    self.disabledTextColor = dynamicDisabledTextColor(in: interfaceStyle)
  }

  private var labelTopConstraint: NSLayoutConstraint?
  private var labelLeadingConstraint: NSLayoutConstraint?
  private var labelBottomConstraint: NSLayoutConstraint?
  private var labelTrailingConstraint: NSLayoutConstraint?

  private func setup() {
    mut(label) {
      .combined(
        .numberOfLines(0),
        .lineBreakMode(.byWordWrapping),
        .textColor(textColor),
        .subview(of: self),
        .topAnchor(.equalTo, topAnchor, referenceOutput: &labelTopConstraint),
        .leadingAnchor(.equalTo, leadingAnchor, referenceOutput: &labelLeadingConstraint),
        .bottomAnchor(.equalTo, bottomAnchor, referenceOutput: &labelBottomConstraint),
        .trailingAnchor(.equalTo, trailingAnchor, referenceOutput: &labelTrailingConstraint)
      )
    }
  }
}
