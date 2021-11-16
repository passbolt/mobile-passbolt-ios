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
import Commons
import UIKit

public class TextViewInput: View {

  public var textPublisher: AnyPublisher<String, Never> {
    textSubject
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
  public var editingDidBeginPublisher: AnyPublisher<Void, Never> { editingDidBeginSubject.eraseToAnyPublisher() }

  public var autocapitalizationType: UITextAutocapitalizationType {
    get { textView.autocapitalizationType }
    set { textView.autocapitalizationType = newValue }
  }
  public var autocorrectionType: UITextAutocorrectionType {
    get { textView.autocorrectionType }
    set { textView.autocorrectionType = newValue }
  }
  public var keyboardType: UIKeyboardType {
    get { textView.keyboardType }
    set { textView.keyboardType = newValue }
  }
  public var attributedPlaceholder: AttributedString? {
    didSet {
      mut(placeholderLabel) {
        .attributedString(attributedPlaceholder)
      }
    }
  }

  public var isRequired: Bool {
    get { !requiredLabel.isHidden }
    set { requiredLabel.isHidden = !newValue }
  }
  public internal(set) var isEditing: Bool = false {
    didSet {
      mut(textView) {
        .when(
          isEditing,
          then: .border(dynamic: .primaryBlue),
          else: .border(dynamic: .divider)
        )
      }
    }
  }

  fileprivate let textView: TextView = .init()
  private var errorMessage: (localizationKey: StaticString, bundle: Bundle)? {
    didSet { updatePresentation() }
  }

  private let descriptionLabel: Label = .init()
  private let accessoryContainer: View = .init()
  private let requiredLabel: Label = .init()
  private let placeholderLabel: Label = .init()
  private let errorMessageView: ErrorMessageView = .init()
  private var isValid: Bool { errorMessage == nil }

  private var placeholderTopConstraint: NSLayoutConstraint?

  private lazy var textSubject: CurrentValueSubject<String, Never> = .init(textView.text)
  private let editingDidBeginSubject: PassthroughSubject<Void, Never> = .init()

  public required init() {
    super.init()

    mut(self) {
      .subview(descriptionLabel, requiredLabel, accessoryContainer)
    }

    mut(descriptionLabel) {
      .combined(
        .font(.inter(ofSize: 12, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .topAnchor(.equalTo, topAnchor),
        .leadingAnchor(.equalTo, leadingAnchor)
      )
    }

    mut(requiredLabel) {
      .combined(
        .font(.inter(ofSize: 12, weight: .semibold)),
        .textColor(dynamic: .secondaryRed),
        .text("*"),
        .leadingAnchor(.equalTo, descriptionLabel.trailingAnchor, constant: 2),
        .centerYAnchor(.equalTo, descriptionLabel.centerYAnchor)
      )
    }

    mut(accessoryContainer) {
      .combined(
        .leadingAnchor(.lessThanOrEqualTo, requiredLabel.trailingAnchor, constant: 8),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, descriptionLabel.topAnchor),
        .centerYAnchor(.equalTo, descriptionLabel.centerYAnchor)
      )
    }

    textView.delegate = self

    mut(textView) {
      .combined(
        .backgroundColor(dynamic: .backgroundAlternative),
        .set(\.textContainer.heightTracksTextView, to: true),
        .set(\.isScrollEnabled, to: false),
        .set(\.attributedString, to: attributedPlaceholder),
        .accessibilityIdentifier("input"),
        .subview(of: self),
        .topAnchor(.equalTo, descriptionLabel.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor, priority: .defaultLow),
        .widthAnchor(.equalTo, widthAnchor)
      )
    }

    mut(placeholderLabel) {
      .combined(
        .placeholderStyle(),
        .subview(of: textView),
        .leadingAnchor(.equalTo, textView.layoutMarginsGuide.leadingAnchor),
        .trailingAnchor(.equalTo, textView.layoutMarginsGuide.trailingAnchor)
      )
    }

    mut(errorMessageView) {
      .combined(
        .accessibilityIdentifier("input.error"),
        .isHidden(true),
        .subview(of: self),
        .topAnchor(.equalTo, textView.bottomAnchor),
        .leadingAnchor(.equalTo, textView.leadingAnchor),
        .trailingAnchor(.equalTo, textView.trailingAnchor),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }
  }

  public func applyOn(text mutation: Mutation<TextView>) {
    mutation.apply(on: textView)

    if let placeholderTopConstraint = placeholderTopConstraint {
      removeConstraint(placeholderTopConstraint)
    }
    else {
      /* NOP */
    }

    mut(placeholderLabel) {
      .topAnchor(
        .equalTo,
        textView.topAnchor,
        constant: textView.contentInset.top,
        referenceOutput: &placeholderTopConstraint
      )
    }
  }

  public func applyOn(description mutation: Mutation<Label>) {
    mutation.apply(on: descriptionLabel)
  }

  public func update(from validated: Validated<String>) {
    if validated.value.isEmpty {
      mut(placeholderLabel) {
        .hidden(false)
      }
    }
    else {
      mut(placeholderLabel) {
        .hidden(true)
      }
      textSubject.value = validated.value
      textView.text = validated.value
    }

    if validated.isValid {
      errorMessage = nil
    }
    else {
      if let localizationKey: StaticString = validated.errors.first?.localizationKey,
        let localizationBundle: Bundle = validated.errors.first?.localizationBundle
      {
        errorMessage = (localizationKey: localizationKey, bundle: localizationBundle)
      }
      else {
        // fallback to display error anyway
        errorMessage = (localizationKey: "resource.form.field.error.invalid", bundle: .commons)
      }
    }
  }

  public func set(
    accessory: UIView,
    with insets: UIEdgeInsets = .zero
  ) {
    accessory.removeFromSuperview()
    mut(accessoryContainer) {
      .combined(
        .custom { (subject: View) in
          subject.subviews.forEach { $0.removeFromSuperview() }
        },
        .subview(accessory)
      )
    }

    mut(accessory) {
      .combined(
        .trailingAnchor(.equalTo, accessoryContainer.trailingAnchor, constant: -insets.right),
        .centerYAnchor(.equalTo, accessoryContainer.centerYAnchor)
      )
    }
  }

  private func updatePresentation() {
    if let (localizationKey, bundle): (StaticString, Bundle) = errorMessage {
      mut(errorMessageView) {
        .combined(
          .text(
            localized: localizationKey,
            inBundle: bundle
          ),
          .isHidden(false)
        )
      }

      mut(textView) {
        .border(dynamic: .secondaryRed)
      }

      mut(descriptionLabel) {
        .textColor(dynamic: .secondaryRed)
      }
    }
    else {
      mut(errorMessageView) {
        .combined(
          .text(""),
          .isHidden(true)
        )
      }

      mut(textView) {
        .when(
          isEditing,
          then: .border(dynamic: .primaryBlue),
          else: .border(dynamic: .divider)
        )
      }

      mut(descriptionLabel) {
        .textColor(dynamic: .primaryText)
      }
    }
    mut(placeholderLabel) {
      .hidden(!textView.text.isEmpty)
    }
  }
}

extension TextViewInput: UITextViewDelegate {

  public func textViewDidChange(_ textView: UITextView) {
    if !textView.text.isEmpty {
      mut(placeholderLabel) {
        .hidden(true)
      }
    }
    else {
      mut(placeholderLabel) {
        .hidden(false)
      }
    }

    textSubject.send(textView.text ?? "")
  }

  public func textViewDidBeginEditing(_ textView: UITextView) {
    editingDidBeginSubject.send(())
    updatePresentation()
    isEditing = true
  }

  public func textViewDidEndEditing(_ textView: UITextView) {
    updatePresentation()
    isEditing = false
  }
}
