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

import Accounts
import CommonModels
import Crypto
import Features
import UICommons

public final class ResourceEditView: KeyboardAwareView {

  internal typealias FieldWithView = (field: ResourceField, view: PlainView)

  internal var generateTapPublisher: AnyPublisher<Void, Never> { generateButton.tapPublisher }
  internal var lockTapPublisher: AnyPublisher<Bool, Never> { lockTapSubject.eraseToAnyPublisher() }
  internal var createTapPublisher: AnyPublisher<Void, Never> { createButton.tapPublisher }

  private let lockTapSubject: PassthroughSubject<Bool, Never> = .init()
  private let scrolledStack: ScrolledStackView = .init()
  private let entropyView: EntropyView = .init()
  private let generateButton: ImageButton = .init()
  private let createButton: TextButton = .init()

  private var fieldViews: OrderedDictionary<ResourceField, PlainView> = .init()

  internal required init(createsNewResource: Bool) {
    super.init()

    mut(scrolledStack) {
      .combined(
        .clipsToBounds(true),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, safeAreaLayoutGuide.topAnchor),
        .bottomAnchor(.equalTo, keyboardLayoutGuide.topAnchor),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 16, right: 16)),
        .backgroundColor(dynamic: .background)
      )
    }

    mut(createButton) {
      .combined(
        .primaryStyle(),
        .when(
          createsNewResource,
          then: .when(
            isInExtensionContext,
            then: .text(
              displayable: .localized(
                key: "resource.form.create.and.fill.button.title"
              )
            ),
            else: .text(
              displayable: .localized(
                key: "resource.form.create.button.title"
              )
            )
          ),
          else: .text(
            displayable: .localized(
              key: "resource.form.update.button.title"
            )
          )
        )
      )
    }

    mut(generateButton) {
      .combined(
        .imageContentMode(.center),
        .imageInsets(.init(top: 8, left: 8, bottom: -8, right: -8)),
        .image(named: .dice, from: .uiCommons),
        .tintColor(dynamic: .iconAlternative),
        .backgroundColor(dynamic: .divider),
        .border(dynamic: .divider, width: 1),
        .cornerRadius(4)
      )
    }
  }

  @available(*, unavailable)
  required init() {
    unreachable("use init(createsNewResource:)")
  }

  internal func update(with fields: OrderedSet<ResourceField>) {
    fieldViews =
      fields
      .compactMap { resourceField -> (field: ResourceField, view: PlainView)? in
        switch resourceField.name {
        case "name":
          return (
            field: resourceField,
            view: Mutation<TextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(true),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .localized(
                            key: "resource.edit.name.field.placeholder"
                          ),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(displayable: .localized(key: "resource.edit.field.name.label"))
                  )
                }
              )
              .instantiate()
          )

        case "uri":
          return (
            field: resourceField,
            view: Mutation<TextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(resourceField.required),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .localized(key: "resource.edit.url.field.placeholder"),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(displayable: .localized(key: "resource.edit.field.url.label"))
                  )
                }
              )
              .instantiate()
          )

        case "username":
          return (
            field: resourceField,
            view: Mutation<TextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(resourceField.required),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .localized(key: "resource.edit.username.field.placeholder"),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(displayable: .localized(key: "resource.edit.field.username.label"))
                  )
                }
              )
              .instantiate()
          )

        case "password", "secret":
          return (
            field: resourceField,
            view: Mutation<SecureTextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(resourceField.required),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .localized(key: "resource.edit.password.field.placeholder"),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(displayable: .localized(key: "resource.edit.field.password.label"))
                  )
                }
              )
              .instantiate()
          )

        case "description":
          return (
            field: resourceField,
            view: Mutation<TextViewInput>
              .combined(
                .isRequired(resourceField.required),
                .attributedPlaceholder(
                  .displayable(
                    .localized(key: "resource.edit.description.field.placeholder"),
                    font: .inter(ofSize: 14, weight: .medium),
                    color: .secondaryText
                  )
                ),
                .custom { (input: TextViewInput) in
                  input.applyOn(
                    text: .formStyle()
                  )
                  input.applyOn(
                    description: .text(
                      displayable: .localized(key: "resource.edit.field.description.label")
                    )
                  )
                  input.set(
                    accessory: Mutation<ImageButton>
                      .combined(
                        .enabled(),
                        .action { [weak self] in
                          self?.lockTapSubject.send(resourceField.encrypted)
                        },
                        .image(
                          named: resourceField.encrypted
                            ? .lockedLock
                            : .unlockedLock,
                          from: .uiCommons
                        ),
                        .tintColor(dynamic: .iconAlternative),
                        .aspectRatio(1),
                        .heightAnchor(.equalTo, constant: 16)
                      )
                      .instantiate(),
                    with: .zero
                  )
                }
              )
              .instantiate()
          )

        case let name where resourceField.encrypted:
          return (
            field: resourceField,
            view: Mutation<SecureTextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(resourceField.required),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .raw(name),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(
                      displayable: .raw(name)
                    )
                  )
                }
              )
              .instantiate()
          )

        case let name:
          return (
            field: resourceField,
            view: Mutation<TextInput>
              .combined(
                .backgroundColor(dynamic: .background),
                .isRequired(resourceField.required),
                .custom { (input: TextInput) in
                  input.applyOn(
                    text: .combined(
                      .primaryStyle(),
                      .attributedPlaceholderString(
                        .displayable(
                          .raw(name),
                          font: .inter(ofSize: 14, weight: .medium),
                          color: .secondaryText
                        )
                      )
                    )
                  )
                  input.applyOn(
                    description: .text(
                      displayable: .raw(name)
                    )
                  )
                }
              )
              .instantiate()
          )
        }
      }
      .reduce(
        into: OrderedDictionary<ResourceField, PlainView>(),
        { (partialResult, fieldWithView: FieldWithView) in
          partialResult[fieldWithView.field] = fieldWithView.view
        }
      )

    scrolledStack.removeAllArrangedSubviews()

    mut(scrolledStack) {
      .combined(
        .forEach(
          in: fieldViews.elements,
          { [unowned self] fieldView in
            switch fieldView.key.name {
            case "password", "secret":
              let container: PlainView =
                Mutation
                .combined(
                  .backgroundColor(dynamic: .background)
                )
                .instantiate()

              mut(fieldView.value) {
                .combined(
                  .subview(of: container),
                  .leadingAnchor(.equalTo, container.leadingAnchor),
                  .trailingAnchor(.equalTo, container.trailingAnchor, constant: -60),
                  .topAnchor(.equalTo, container.topAnchor)
                )
              }

              let textFieldCenterYAnchor: NSLayoutYAxisAnchor =
                (fieldView.value as? TextInput)?.textFieldCenterYAnchor ?? fieldView.value.centerYAnchor

              mut(self.generateButton) {
                .combined(
                  .subview(of: container),
                  .trailingAnchor(.equalTo, container.trailingAnchor),
                  .centerYAnchor(.equalTo, textFieldCenterYAnchor),
                  .widthAnchor(.equalTo, constant: 48),
                  .aspectRatio(1)
                )
              }

              mut(self.entropyView) {
                .combined(
                  .subview(of: container),
                  .leadingAnchor(.equalTo, container.leadingAnchor),
                  .trailingAnchor(.equalTo, fieldView.value.trailingAnchor),
                  .topAnchor(.equalTo, fieldView.value.bottomAnchor),
                  .bottomAnchor(.equalTo, container.bottomAnchor)
                )
              }

              return .combined(
                .append(container),
                .appendSpace(of: 4)
              )

            case _:
              return .combined(
                .append(fieldView.value),
                .appendSpace(of: 4)
              )
            }
          }
        ),
        .appendFiller(minSize: 20),
        .append(createButton)
      )
    }
  }

  internal func update(
    validated: Validated<String>,
    for field: ResourceField
  ) {
    guard let fieldView: PlainView = fieldViews.first(where: { $0.key == field })?.value
    else {
      assertionFailure("Missing field for key: \(field)")
      return
    }

    switch field.name {
    case "description":
      guard let textViewInput: TextViewInput = fieldView as? TextViewInput
      else {
        assertionFailure("Field is not a TextViewInput")
        return
      }

      textViewInput.update(from: validated)
    case _:
      guard let textInput: TextInput = fieldView as? TextInput
      else {
        assertionFailure("Field is not a TextInput")
        return
      }

      textInput.update(from: validated)
    }
  }

  internal func fieldValuePublisher(
    for field: ResourceField
  ) -> AnyPublisher<String, Never> {
    guard let fieldView: PlainView = fieldViews.first(where: { $0.key == field })?.value
    else {
      return Empty()
        .eraseToAnyPublisher()
    }

    switch field.name {
    case "description":
      guard let textViewInput: TextViewInput = fieldView as? TextViewInput
      else {
        return Empty()
          .eraseToAnyPublisher()
      }

      return textViewInput.textPublisher

    case _:
      guard let textInput: TextInput = fieldView as? TextInput
      else {
        return Empty()
          .eraseToAnyPublisher()
      }

      return textInput.textPublisher
    }
  }

  internal func update(entropy: Entropy) {
    entropyView.update(entropy: entropy)
  }
}
