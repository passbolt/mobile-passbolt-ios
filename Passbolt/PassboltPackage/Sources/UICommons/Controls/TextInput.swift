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

public class TextInput: View {

  public let textPublisher: AnyPublisher<String, Never>
  public let editingDidBeginPublisher: AnyPublisher<Void, Never>
  public var attributedPlaceholder: NSAttributedString? {
    get { textField.attributedPlaceholder }
    set { textField.attributedPlaceholder = newValue }
  }
  public var autocapitalizationType: UITextAutocapitalizationType {
    get { textField.autocapitalizationType }
    set { textField.autocapitalizationType = newValue }
  }
  public var autocorrectionType: UITextAutocorrectionType {
    get { textField.autocorrectionType }
    set { textField.autocorrectionType = newValue }
  }
  public var keyboardType: UIKeyboardType {
    get { textField.keyboardType }
    set { textField.keyboardType = newValue }
  }

  public var isRequired: Bool {
    get { !requiredLabel.isHidden }
    set { requiredLabel.isHidden = !newValue }
  }

  public var textFieldCenterYAnchor: NSLayoutYAxisAnchor { textField.centerYAnchor }

  fileprivate let textField: TextField = .init()
  private var errorMessage: (localizationKey: StaticString, bundle: Bundle)? {
    didSet { updatePresentation() }
  }

  private let descriptionLabel: Label = .init()
  private let requiredLabel: Label = .init()
  private let errorMessageView: ErrorMessageView = .init()
  private var isValid: Bool { errorMessage == nil }

  public required init() {
    let textSubject: PassthroughSubject<String, Never> = .init()
    let editingDidBeginSubject: PassthroughSubject<Void, Never> = .init()

    self.textPublisher = textSubject.eraseToAnyPublisher()
    self.editingDidBeginPublisher = editingDidBeginSubject.eraseToAnyPublisher()
    super.init()

    mut(self) {
      .subview(descriptionLabel, requiredLabel)
    }

    mut(descriptionLabel) {
      .combined(
        .font(.inter(ofSize: 12, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .topAnchor(.equalTo, topAnchor),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, requiredLabel.leadingAnchor, constant: -2)
      )
    }

    mut(requiredLabel) {
      .combined(
        .font(.inter(ofSize: 12, weight: .semibold)),
        .textColor(dynamic: .secondaryRed),
        .text("*"),
        .topAnchor(.equalTo, topAnchor),
        .bottomAnchor(.equalTo, descriptionLabel.bottomAnchor)
      )
    }

    mut(textField) {
      .combined(
        .primaryStyle(),
        .accessibilityIdentifier("input"),
        .action(
          { textInput in
            textSubject.send(textInput.text ?? "")
          },
          for: .editingChanged
        ),
        .action(
          { [weak self] _ in
            editingDidBeginSubject.send(())

            self?.updatePresentation()
          },
          for: .editingDidBegin
        ),
        .action(
          { [weak self] _ in
            self?.updatePresentation()
          },
          for: .editingDidEnd
        ),
        .subview(of: self),
        .topAnchor(.equalTo, descriptionLabel.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .bottomAnchor(.equalTo, bottomAnchor, priority: .defaultLow)
      )
    }

    mut(errorMessageView) {
      .combined(
        .accessibilityIdentifier("input.error"),
        .isHidden(true),
        .subview(of: self),
        .topAnchor(.equalTo, textField.bottomAnchor),
        .leadingAnchor(.equalTo, textField.leadingAnchor),
        .trailingAnchor(.equalTo, textField.trailingAnchor),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }
  }

  public func applyOn(text mutation: Mutation<TextField>) {
    mutation.apply(on: textField)
  }

  public func applyOn(description mutation: Mutation<Label>) {
    mutation.apply(on: descriptionLabel)
  }

  public func update(from validated: Validated<String>) {
    textField.text = validated.value

    if let localizationKey: StaticString = validated.errors.first?.localizationKey,
      let localizationBundle: Bundle = validated.errors.first?.localizationBundle
    {
      errorMessage = (localizationKey: localizationKey, bundle: localizationBundle)
    }
    else {
      errorMessage = nil
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

      mut(textField) {
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

      mut(textField) {
        .when(
          textField.isEditing,
          then: .border(dynamic: .primaryBlue),
          else: .border(dynamic: .divider)
        )
      }

      mut(descriptionLabel) {
        .textColor(dynamic: .primaryText)
      }
    }
  }
}

public final class SecureTextInput: TextInput {

  private let imageButton: ImageButton = .init()

  public required init() {
    super.init()

    let buttonStyle: Mutation<ImageButton> = .with(
      { [weak self] in
        self?.textField.isSecureTextEntry ?? false
      },
      { isSecureTextEntry in
        .when(
          isSecureTextEntry,
          then: .image(named: .eye, from: .uiCommons),
          else: .image(named: .eyeSlash, from: .uiCommons)
        )
      }
    )

    mut(imageButton) {
      .combined(
        .accessibilityIdentifier("input.secure.button.eye"),
        .tintColor(dynamic: .icon),
        .action { [weak self] in
          guard let self = self else { return }
          self.textField.isSecureTextEntry.toggle()

          buttonStyle.apply(on: self.imageButton)
        }
      )
    }

    textField.returnKeyType = .done
    textField.endEditingOnReturn = true
    textField.isSecureTextEntry = true
    textField.autocorrectionType = .no
    textField.rightViewMode = .always
    textField.rightView = imageButton

    buttonStyle.apply(on: imageButton)
  }
}
