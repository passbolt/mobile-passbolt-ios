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
import UICommons
import Accounts

internal final class ResourceCreateView: ScrolledStackView {

  internal typealias FieldWithView = (field: ResourceCreateController.Field, view: View)

  private let nameInput: TextInput = .init()
  private let urlInput: TextInput = .init()
  private let usernameInput: TextInput = .init()
  private let passwordInput: SecureTextInput = .init()
  private let descriptionInput: TextViewInput = .init()

  private var fieldViews: Dictionary<ResourceCreateController.Field, View> = .init()

  @available(*, unavailable, message: "Use init(resourceFields:)")
  internal required init() {
    unreachable("Use init(resourceFields:)")
  }

  internal init(resourceFields: Array<ResourceCreateController.Field>) {
    super.init()

    fieldViews = resourceFields.compactMap { resourceField -> (ResourceCreateController.Field, View) in
      switch resourceField {
      case let .name(required, _, _):
        return (
          field: resourceField,
          view: Mutation<TextInput>
            .combined(
              .backgroundColor(dynamic: .background),
              .isRequired(required),
              .custom { (input: TextInput) in
                input.applyOn(
                  text: .combined(
                    .primaryStyle(),
                    .attributedPlaceholderString(
                      .localized(
                        "resource.create.name.field.placeholder",
                        inBundle: .main,
                        font: .inter(ofSize: 14, weight: .medium),
                        color: .secondaryText
                      )
                    )
                  )
                )
                input.applyOn(
                  description: .text(localized: "resource.create.field.name.label", inBundle: .main)
                )
              }
            )
            .instantiate()
        )

      case let .uri(required, _, _):
        return (
          field: resourceField,
          view: Mutation<TextInput>
            .combined(
              .backgroundColor(dynamic: .background),
              .isRequired(required),
              .custom { (input: TextInput) in
                input.applyOn(
                  text: .combined(
                    .primaryStyle(),
                    .attributedPlaceholderString(
                      .localized(
                        "resource.create.url.field.placeholder",
                        inBundle: .main,
                        font: .inter(ofSize: 14, weight: .medium),
                        color: .secondaryText
                      )
                    )
                  )
                )
                input.applyOn(
                  description: .text(localized: "resource.create.field.url.label", inBundle: .main)
                )
              }
            )
            .instantiate()
        )

      case let .username(required, _, _):
        return (
          field: resourceField,
          view: Mutation<TextInput>
            .combined(
              .backgroundColor(dynamic: .background),
              .isRequired(required),
              .custom { (input: TextInput) in
                input.applyOn(
                  text: .combined(
                    .primaryStyle(),
                    .attributedPlaceholderString(
                      .localized(
                        "resource.create.username.field.placeholder",
                        inBundle: .main,
                        font: .inter(ofSize: 14, weight: .medium),
                        color: .secondaryText
                      )
                    )
                  )
                )
                input.applyOn(
                  description: .text(localized: "resource.create.field.username.label", inBundle: .main)
                )
              }
            )
            .instantiate()
        )

      case let .password(required, _, _):
        return (
          field: resourceField,
          view: Mutation<SecureTextInput>
            .combined(
              .backgroundColor(dynamic: .background),
              .isRequired(required),
              .custom { (input: TextInput) in
                input.applyOn(
                  text: .combined(
                    .primaryStyle(),
                    .attributedPlaceholderString(
                      .localized(
                        "resource.create.password.field.placeholder",
                        inBundle: .main,
                        font: .inter(ofSize: 14, weight: .medium),
                        color: .secondaryText
                      )
                    )
                  )
                )
                input.applyOn(
                  description: .text(localized: "resource.create.field.password.label", inBundle: .main)
                )
              }
            )
            .instantiate()
        )

      case let .description(required, _, _):
        return (
          field: resourceField,
          view: Mutation<TextViewInput>
            .combined(
              .backgroundColor(dynamic: .background),
              .isRequired(required),
              .attributedPlaceholder(
                .localized(
                  "resource.create.description.field.placeholder",
                  inBundle: .main,
                  font: .inter(ofSize: 14, weight: .medium),
                  color: .secondaryText
                )
              ),
              .isRequired(false),
              .custom { (input: TextViewInput) in
                input.applyOn(text:
                                  .formStyle()
                )
                input.applyOn(
                  description: .text(localized: "resource.create.field.description.label", inBundle: .main)
                )
              }
            )
            .instantiate()
        )
      }
    }
    .reduce(into: Dictionary<ResourceCreateController.Field, View>(), { (partialResult, fieldWithView: FieldWithView)  in
      partialResult[fieldWithView.field] = fieldWithView.view
    })

    mut(self) {
      .combined(
        .axis(.vertical),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 0, left: 16, bottom: 16, right: 16)),
        .forEach(
          in: fieldViews.sorted { $0.key < $1.key }, { fieldView in
              .combined(
                .append(fieldView.value),
                .appendSpace(of: 4)
              )
          }
        ),
        .appendFiller(minSize: 20)
      )
    }
  }
}
