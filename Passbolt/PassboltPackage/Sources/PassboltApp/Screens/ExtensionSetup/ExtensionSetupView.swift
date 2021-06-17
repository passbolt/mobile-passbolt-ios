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

internal final class ExtensionSetupView: ScrolledStackView {
  
  internal var setupTapPublisher: AnyPublisher<Void, Never>
  internal var skipTapPublisher: AnyPublisher<Void, Never>
  
  // swiftlint:disable:next function_body_length
  internal required init() {
    let setupButton: TextButton = .init()
    let skipButton: TextButton = .init()
    
    self.setupTapPublisher = setupButton.tapPublisher
    self.skipTapPublisher = skipButton.tapPublisher
    
    super.init()
    
    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .titleStyle(),
        .text(localized: "extension.setup.title")
      )
    }
    
    let settingsStep: StepListItemView = .init()
    mut(settingsStep) {
      .combined(
        .iconView(
          Mutation<ImageView>
            .image(dynamic: .settingsIcon)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .localized(
              "extension.setup.settings.step",
              withBoldSubstringLocalized: "extension.setup.settings.step.bold",
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
            .image(dynamic: .keyboardIcon)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .localized(
              "extension.setup.keyboard.step",
              withBoldSubstringLocalized: "extension.setup.keyboard.step.bold",
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
            .image(dynamic: .switchIcon)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .localized(
              "extension.setup.switch.step",
              withBoldSubstringLocalized: "extension.setup.switch.step.bold",
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
            .image(dynamic: .keychainIcon)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .localized(
              "extension.setup.keychain.step",
              withBoldSubstringLocalized: "extension.setup.keychain.step.bold",
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
            .image(dynamic: .passboltIcon)
            .instantiate()
        ),
        .label(
          mutatation: .attributedString(
            .localized(
              "extension.setup.passbolt.step",
              withBoldSubstringLocalized: "extension.setup.passbolt.step.bold",
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
        .text(localized: "extension.setup.setup.button"),
        .accessibilityIdentifier("extension.setup.setup.button")
      )
    }
    
    mut(skipButton) {
      .combined(
        .linkStyle(),
        .text(localized: "extension.setup.later.button"),
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
        .append(skipButton)
      )
    }
  }
}
