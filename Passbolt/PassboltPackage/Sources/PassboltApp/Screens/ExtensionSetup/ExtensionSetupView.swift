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

import Display
import Localization
import SwiftUI
import UICommons

internal struct ExtensionSetupView: ControlledView {

  internal let controller: ExtensionSetupViewController

  internal init(
    controller: ExtensionSetupViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 24) {
        Text(displayable: "extension.setup.title")
          .text(
            font: .inter(
              ofSize: 24,
              weight: .semibold
            ),
            color: .passboltPrimaryText
          )
          .multilineTextAlignment(.center)

        VStack(alignment: .leading, spacing: 0) {
          ExtensionStepView(
            icon: .settingsIcon,
            text: .displayable(
              "extension.setup.settings.step",
              withBoldSubstring: "extension.setup.settings.step.bold",
              fontSize: 14,
              color: .primaryText
            )
          )
          divider
          ExtensionStepView(
            icon: .keyboardIcon,
            text: .displayable(
              "extension.setup.keyboard.step",
              withBoldSubstring: "extension.setup.keyboard.step.bold",
              fontSize: 14,
              color: .primaryText
            )
          )
          divider
          ExtensionStepView(
            icon: .switchIcon,
            text: .displayable(
              "extension.setup.switch.step",
              withBoldSubstring: "extension.setup.switch.step.bold",
              fontSize: 14,
              color: .primaryText
            )
          )
          divider
          ExtensionStepView(
            icon: .keychainIcon,
            text: .displayable(
              "extension.setup.keychain.step",
              withBoldSubstring: "extension.setup.keychain.step.bold",
              fontSize: 14,
              color: .primaryText
            )
          )
          divider
          ExtensionStepView(
            icon: .passboltIcon,
            text: .displayable(
              "extension.setup.passbolt.step",
              withBoldSubstring: "extension.setup.passbolt.step.bold",
              fontSize: 14,
              color: .primaryText
            )
          )
        }
      }

      Spacer(minLength: 8)

      VStack(spacing: 16) {
        PrimaryButton(
          title: .localized(key: "extension.setup.setup.button"),
          action: {
            await controller.setupExtension()
          }
        )
        .accessibilityIdentifier("extension.setup.setup.button")
        when(\.showSkipButton) {
          SecondaryButton(
            title: .localized(key: "extension.setup.later.button"),
            action: {
              await controller.skipSetup()
            }
          )
          .accessibilityIdentifier("extension.setup.later.button")
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 24)
    .padding(.bottom, 8)
    .frame(maxHeight: .infinity)
    .background(Color.passboltBackground)
    .interactiveDismissDisabled()
    .onAppear(perform: self.controller.dismissIfNeeded)
    .useCustomBackButton()
    .toolbar {
      ToolbarItem(placement: .principal) {
        Rectangle()
          .foregroundColor(.clear)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var divider: some View {
    Rectangle()
      .frame(width: 1, height: 16)
      .foregroundColor(.passboltDivider)
      .padding(.leading, 12)
      .padding(.top, 8)
      .padding(.bottom, 8)
  }
}

private struct ExtensionStepView: View {

  @Environment(\.colorScheme) var colorScheme
  let icon: ImageNameConstant
  let text: UICommons.AttributedString

  private var interfaceStyle: UIUserInterfaceStyle {
    switch colorScheme {
    case .light:
      return .light
    case .dark:
      return .dark
    @unknown default:
      return .unspecified
    }
  }

  var body: some View {
    HStack(spacing: 16) {
      Image(named: icon)
        .resizable()
        .frame(width: 24, height: 24)
        .foregroundColor(.passboltPrimaryBlue)

      Text(text.nsAttributedString(in: interfaceStyle).toAttributedString())
        .text(
          font: .inter(ofSize: 14),
          color: .passboltSecondaryText
        )
        .multilineTextAlignment(.leading)

      Spacer()
    }
  }
}

extension NSAttributedString {

  func toAttributedString() -> SwiftUI.AttributedString {
    AttributedString(self)
  }
}
