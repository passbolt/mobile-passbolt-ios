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
import UICommons

internal final class AccountDetailsView: KeyboardAwareView {

  internal var accountLabelPublisher: AnyPublisher<String, Never> {
    labelTextInput.textPublisher
  }
  internal let saveChangesPublisher: AnyPublisher<Void, Never>
  private let avatarImageView: ImageView = .init()
  private let labelTextInput: TextInput = .init()
  private let cancellables: Cancellables = .init()

  internal init(
    accountWithProfile: AccountWithProfile
  ) {
    let saveChangesSubject: PassthroughSubject<Void, Never> = .init()
    self.saveChangesPublisher = saveChangesSubject.eraseToAnyPublisher()
    super.init()

    mut(self) {
      .backgroundColor(dynamic: .background)
    }

    let avatarContainer: ContainerView<ImageView> = .init(
      contentView: avatarImageView,
      mutation: .combined(
        .image(named: .person, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(.clear),
        .border(dynamic: .divider),
        .cornerRadius(48, masksToBounds: true),
        .widthAnchor(.equalTo, constant: 96),
        .heightAnchor(.equalTo, constant: 96)
      ),
      heightMultiplier: 1
    )
    mut(labelTextInput) {
      .combined(
        .isRequired(false),
        .custom { (input: TextInput) in
          input.applyOn(
            text: .combined(
              .primaryStyle(),
              .attributedPlaceholderString(
                .string(
                  "\(accountWithProfile.firstName) \(accountWithProfile.lastName)",
                  attributes: .init(
                    font: .inter(ofSize: 14, weight: .medium),
                    color: .secondaryText
                  ),
                  tail: .terminator
                )
              )
            )
          )
          input.applyOn(
            description: .text(
              localized: "account.details.field.label.title"
            )
          )
        }
      )
    }
    let editingInfoLabel: Label = .init()
    mut(editingInfoLabel) {
      .combined(
        .text(localized: "account.details.field.label.editing.info"),
        .font(.inter(ofSize: 12, weight: .regular)),
        .textColor(dynamic: .secondaryText),
        .numberOfLines(0)
      )
    }

    let saveChangesButton: TextButton = .init()
    mut(saveChangesButton) {
      .combined(
        .text(localized: "account.details.button.save.title"),
        .primaryStyle(),
        .action { saveChangesSubject.send() }
      )
    }

    let accountDetailsScrolledStack: ScrolledStackView = .init()
    mut(accountDetailsScrolledStack) {
      .combined(
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 24, left: 16, bottom: 8, right: 16)),
        .subview(of: self),
        .topAnchor(.equalTo, topAnchor),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .bottomAnchor(.equalTo, keyboardSafeAreaLayoutGuide.bottomAnchor, constant: -8),
        .append(avatarContainer),
        .appendSpace(of: 16),
        .append(labelTextInput),
        .append(editingInfoLabel),
        .appendSpace(of: 16),
        .append(
          Mutation<KeyValueView>
            .combined(
              Mutation<Label>
                .combined(
                  .text(localized: "account.details.field.name.title")
                )
                .contramap(\KeyValueView.titleLabel),
              Mutation<TextView>
                .combined(
                  .text("\(accountWithProfile.firstName) \(accountWithProfile.lastName)")
                )
                .contramap(\KeyValueView.valueTextView)
            )
            .instantiate()
        ),
        .appendSpace(of: 12),
        .append(
          Mutation<KeyValueView>
            .combined(
              Mutation<Label>
                .combined(
                  .text(localized: "account.details.field.email.title")
                )
                .contramap(\KeyValueView.titleLabel),
              Mutation<TextView>
                .combined(
                  .text(accountWithProfile.username)
                )
                .contramap(\KeyValueView.valueTextView)
            )
            .instantiate()
        ),
        .appendSpace(of: 12),
        .append(
          Mutation<KeyValueView>
            .combined(
              Mutation<Label>
                .combined(
                  .text(localized: "account.details.field.url.title")
                )
                .contramap(\KeyValueView.titleLabel),
              Mutation<TextView>
                .combined(
                  .text(accountWithProfile.domain.rawValue)
                )
                .contramap(\KeyValueView.valueTextView)
            )
            .instantiate()
        ),
        .appendFiller(minSize: 12),
        .append(saveChangesButton)
      )
    }
  }

  @available(*, unavailable)
  internal required init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  internal func updateAccountLabel(text: Validated<String>) {
    labelTextInput.update(from: text)
  }

  internal func updateAccountAvatar(image: UIImage?) {
    mut(avatarImageView) {
      .whenSome(
        image,
        then: { image in
          .image(image)
        },
        else: .image(
          named: .person,
          from: .uiCommons
        )
      )
    }
  }
}

private final class KeyValueView: View {

  fileprivate var titleLabel: Label = .init()
  fileprivate var valueTextView: TextView = .init()

  override func setup() {
    super.setup()

    mut(self) {
      .combined(
        .heightAnchor(.greaterThanOrEqualTo, constant: 52)
      )
    }

    mut(titleLabel) {
      .combined(
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, topAnchor, constant: 4),
        .textColor(dynamic: .primaryText),
        .font(.inter(ofSize: 12, weight: .semibold))
      )
    }

    mut(valueTextView) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, titleLabel.bottomAnchor, constant: 8),
        .leadingAnchor(.equalTo, titleLabel.leadingAnchor),
        .trailingAnchor(.equalTo, titleLabel.trailingAnchor),
        .heightAnchor(.greaterThanOrEqualTo, constant: 20),
        .bottomAnchor(.equalTo, bottomAnchor, constant: -8),
        .textColor(dynamic: .secondaryText),
        .lineBreakMode(.byWordWrapping),
        .font(.inter(ofSize: 14, weight: .medium)),
        .set(\.contentInset, to: .zero),
        .set(\.textContainerInset, to: .init(top: 0, left: -5, bottom: 0, right: 0)),
        .set(\.isScrollEnabled, to: false),
        .set(\.isEditable, to: false)
      )
    }
  }
}
