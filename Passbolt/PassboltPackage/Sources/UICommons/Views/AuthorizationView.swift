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

import Commons

public final class AuthorizationView: KeyboardAwareView {
  
  public var secureTextPublisher: AnyPublisher<String, Never> { passwordInput.textPublisher }
  public var biometricTapPublisher: AnyPublisher<Void, Never> { biometricButton.tapPublisher }
  public var signInTapPublisher: AnyPublisher<Void, Never> { signInButton.tapPublisher }
  public var forgotTapPublisher: AnyPublisher<Void, Never> { forgotButton.tapPublisher }
  
  private let avatar: ImageView = .init()
  private let nameLabel: Label = .init()
  private let emailLabel: Label = .init()
  private let urlLabel: Label = .init()
  private let passwordInput: SecureTextInput = .init()
  private let biometricButton: ImageButton = .init()
  private let signInButton: TextButton = .init()
  private let forgotButton: TextButton = .init()
  
  public required init() {
    super.init()
    
    let avatarParent: View = Mutation<View>
      .combined(
        .backgroundColor(dynamic: .background),
        .heightAnchor(.equalTo, constant: 96)
      )
      .instantiate()
    
    let avatarContainer: View = Mutation<View>
      .combined(
        .subview(of: avatarParent),
        .backgroundColor(dynamic: .background),
        .cornerRadius(48),
        .border(dynamic: .divider),
        .widthAnchor(.equalTo, constant: 96),
        .heightAnchor(.equalTo, constant: 96),
        .centerXAnchor(.equalTo, avatarParent.centerXAnchor),
        .centerYAnchor(.equalTo, avatarParent.centerYAnchor)
      )
      .instantiate()
    
    mut(avatar) {
      .combined(
        .subview(of: avatarContainer),
        .image(named: .person, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .edges(
          equalTo: avatarContainer,
          insets: .init(top: -24, left: -24, bottom: -24, right: -24)
        )
      )
    }
    
    setupLabels()
    
    let buttonContainer: View = Mutation<View>
      .combined(
        .backgroundColor(dynamic: .background),
        .heightAnchor(.equalTo, constant: 56)
      )
      .instantiate()
    
    let biometricButtonContainer: View = Mutation<View>
      .combined(
        .subview(of: buttonContainer),
        .backgroundColor(dynamic: .background),
        .border(dynamic: .divider),
        .cornerRadius(28),
        .centerXAnchor(.equalTo, buttonContainer.centerXAnchor),
        .centerYAnchor(.equalTo, buttonContainer.centerYAnchor),
        .widthAnchor(.equalTo, constant: 56),
        .heightAnchor(.equalTo, constant: 56)
      )
      .instantiate()
    
    mut(biometricButton) {
      .combined(
        .subview(of: biometricButtonContainer),
        .contentMode(.scaleAspectFit),
        .image(symbol: Bool.random() ? .faceId : .touchId),
        .tintColor(dynamic: .primaryBlue),
        .edges(
          equalTo: biometricButtonContainer,
          insets: .init(top: -12, left: -12, bottom: -12, right: -12)
        )
      )
    }
    
    passwordInput.applyOn(
      description: .text(
        localized: "authorization.passphrase.description.text"
      )
    )

    setupBottomButtons()
    
    Mutation<ScrolledStackView>
      .combined(
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 0, right: 16)),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, topAnchor),
        .bottomAnchor(.equalTo, keyboardSafeAreaLayoutGuide.bottomAnchor),
        .appendSpace(of: 72),
        .append(avatarParent),
        .appendSpace(of: 20),
        .append(nameLabel),
        .appendSpace(of: 16),
        .append(emailLabel),
        .appendSpace(of: 12),
        .append(urlLabel),
        .appendSpace(of: 32),
        .append(passwordInput),
        .appendSpace(of: 24),
        .append(buttonContainer),
        .appendFiller(minSize: 20),
        .append(signInButton),
        .append(forgotButton)
      )
      .instantiate()
  }
  
  public func applyOn(image mutation: Mutation<ImageView>) {
    mutation.apply(on: avatar)
  }
  
  public func applyOn(name mutation: Mutation<Label>) {
    mutation.apply(on: nameLabel)
  }
  
  public func applyOn(email mutation: Mutation<Label>) {
    mutation.apply(on: emailLabel)
  }
  
  public func applyOn(url mutation: Mutation<Label>) {
    mutation.apply(on: urlLabel)
  }
  
  public func applyOn(biometricButton mutation: Mutation<ImageButton>) {
    mutation.apply(on: biometricButton)
  }
  
  public func applyOn(signInButton mutation: Mutation<Button>) {
    mutation.apply(on: signInButton)
  }
  
  public func applyOn(passwordDescription mutation: Mutation<Label>) {
    passwordInput.applyOn(description: mutation)
  }
  
  public func update(from validated: Validated<String>) {
    passwordInput.update(from: validated)
  }
  
  private func setupLabels() {
    mut(nameLabel) {
      .combined(
        .font(.inter(ofSize: 20, weight: .semibold)),
        .textColor(dynamic: .primaryText),
        .textAlignment(.center)
      )
    }
    
    mut(emailLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .textColor(dynamic: .secondaryText),
        .textAlignment(.center)
      )
    }
    
    mut(urlLabel) {
      .combined(
        .font(.inter(ofSize: 12)),
        .textColor(dynamic: .secondaryText),
        .textAlignment(.center)
      )
    }
    
    mut(passwordInput) {
      .isRequired(true)
    }
  }
  
  private func setupBottomButtons() {
    mut(signInButton) {
      .combined(
        .primaryStyle(),
        .text(localized: "authorization.button.title")
      )
    }
    
    mut(forgotButton) {
      .combined(
        .linkStyle(),
        .text(localized: "authorization.forgot.passphrase.button.title")
      )
    }
  }
}
