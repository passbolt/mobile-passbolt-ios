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
import UICommons

internal final class ExtensionSetupView: ScrolledStackView {

  internal var setupTapPublisher: AnyPublisher<Void, Never>
  internal var skipTapPublisher: AnyPublisher<Void, Never>

  @available(*, unavailable)
  internal required init() {
    unreachable("use init(skipHidden:)")
  }

  internal init(skipHidden: Bool = false) {
    let setupButton: TextButton = .init()
    let skipButton: TextButton = .init()

    self.setupTapPublisher = setupButton.tapPublisher
    self.skipTapPublisher = skipButton.tapPublisher

    super.init()

    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .titleStyle(),
        .text(displayable: .localized(key: "extension.setup.title"))
      )
    }

    let settingsStep: StepListItemView = .init()
    mut(settingsStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(named: .settingsIcon, from: .uiCommons)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .displayable(
              .localized(key: "extension.setup.settings.step"),
              withBoldSubstring: .localized(key: "extension.setup.settings.step.bold"),
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let keyboardStep: StepListItemView = .init()
    mut(keyboardStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(named: .keyboardIcon, from: .uiCommons)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .displayable(
              .localized(key: "extension.setup.keyboard.step"),
              withBoldSubstring: .localized(key: "extension.setup.keyboard.step.bold"),
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let switchStep: StepListItemView = .init()
    mut(switchStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(named: .switchIcon, from: .uiCommons)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .displayable(
              .localized(key: "extension.setup.switch.step"),
              withBoldSubstring: .localized(key: "extension.setup.switch.step.bold"),
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let keychainStep: StepListItemView = .init()
    mut(keychainStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(named: .keychainIcon, from: .uiCommons)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .displayable(
              .localized(key: "extension.setup.keychain.step"),
              withBoldSubstring: .localized(key: "extension.setup.keychain.step.bold"),
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let passboltStep: StepListItemView = .init()
    mut(passboltStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(named: .passboltIcon, from: .uiCommons)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .displayable(
              .localized(key: "extension.setup.passbolt.step"),
              withBoldSubstring: .localized(key: "extension.setup.passbolt.step.bold"),
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let stepListView: StepListView = .init()
    mut(stepListView) {
      .steps(
        settingsStep,
        keyboardStep,
        switchStep,
        keychainStep,
        passboltStep
      )
    }

    mut(setupButton) {
      .combined(
        .primaryStyle(),
        .text(displayable: .localized(key: "extension.setup.setup.button")),
        .accessibilityIdentifier("extension.setup.setup.button")
      )
    }

    mut(skipButton) {
      .combined(
        .linkStyle(),
        .text(displayable: .localized(key: "extension.setup.later.button")),
        .accessibilityIdentifier("extension.setup.later.button")
      )
    }
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 24, left: 16, bottom: 8, right: 16)),
        .append(titleLabel),
        .appendSpace(of: 24),
        .append(stepListView),
        .appendFiller(minSize: 8),
        .append(setupButton),
        .when(
          !skipHidden,
          then: .append(skipButton)
        )
      )
    }
  }
}
