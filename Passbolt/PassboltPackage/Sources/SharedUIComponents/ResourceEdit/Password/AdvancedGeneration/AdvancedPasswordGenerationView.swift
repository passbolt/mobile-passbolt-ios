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
import Display
import SwiftUI

internal struct AdvancedPasswordGenerationView: ControlledView {

  internal let controller: AdvancedPasswordGenerationViewController

  internal init(controller: AdvancedPasswordGenerationViewController) {
    self.controller = controller
  }

  internal var body: some View {
    self.with(\.configuration.defaultGenerator) { (generator: PasswordGeneratorType) in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          self.previewView(for: generator)
          self.tabRow(activeTab: generator)
          self.tabContent(for: generator)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 88)
      }
      .overlay(alignment: .bottom) {
        self.saveButton
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
      }
      .navigationTitle(displayable: Self.navigationTitleKey(for: generator))
      .useCustomBackButton()
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @MainActor @ViewBuilder private func previewView(for generator: PasswordGeneratorType) -> some View {
    self.with(\.preview) { (preview: String) in
      VStack(alignment: .leading, spacing: 4) {
        Text(displayable: Self.previewTitleKey(for: generator))
          .text(font: .inter(ofSize: 12, weight: .semibold), color: .passboltPrimaryText)
        Text(preview)
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.passboltPrimaryText)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.passboltBackgroundAlternative)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(Color.passboltDivider, lineWidth: 1)
          )
          .textSelection(.enabled)
      }
    }
  }

  @MainActor @ViewBuilder private func tabRow(activeTab: PasswordGeneratorType) -> some View {
    HStack(spacing: 8) {
      self.tabButton(
        title: "resource.edit.password.advanced.tab.password",
        isSelected: activeTab == .password,
        action: { self.controller.selectTab(.password) }
      )
      self.tabButton(
        title: "resource.edit.password.advanced.tab.passphrase",
        isSelected: activeTab == .passphrase,
        action: { self.controller.selectTab(.passphrase) }
      )
    }
  }

  @MainActor @ViewBuilder private func tabButton(
    title: DisplayableString,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(displayable: title)
        .font(.inter(ofSize: 14, weight: .medium))
        .foregroundColor(isSelected ? .passboltPrimaryButtonText : .passboltPrimaryText)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.passboltPrimaryBlue : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(isSelected ? Color.passboltPrimaryBlue : Color.passboltDivider, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  @MainActor @ViewBuilder private func tabContent(for generator: PasswordGeneratorType) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      switch generator {
      case .password:
        self.passwordTabContent
      case .passphrase:
        self.passphraseTabContent
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.passboltBackgroundGray)
    )
  }

  @MainActor @ViewBuilder private var passwordTabContent: some View {
    self.withBinding(
      \.configuration.passwordGeneratorSettings.length,
      content: { (length: Binding<Int>) in
        Slider(
          "resource.edit.password.advanced.length.title",
          value: length,
          min: PasswordGeneratorSettings.passwordGenMinPasswordLength,
          max: PasswordGeneratorSettings.passwordGenMaxPasswordLength,
          onCommit: { self.controller.commitChange() }
        )
      }
    )

    Text(displayable: "resource.edit.password.advanced.character_sets.title")
      .text(font: .inter(ofSize: 12, weight: .semibold), color: .passboltPrimaryText)

    self.with(\.configuration.passwordGeneratorSettings) { (settings: PasswordGeneratorSettings) in
      CharacterSetTagCloudView(items: self.characterSetItems(for: settings))
    }

    self.with(\.configuration.passwordGeneratorSettings.excludeLookAlikeChars) { (excluded: Bool) in
      HStack {
        Text(displayable: "resource.edit.password.advanced.exclude_lookalike.title")
          .text(font: .inter(ofSize: 14, weight: .regular), color: .passboltPrimaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
        Toggle(
          "",
          isOn: Binding(
            get: { excluded },
            set: { (newValue: Bool) in self.controller.setExcludeLookAlikeChars(newValue) }
          )
        )
        .labelsHidden()
      }
    }
  }

  @MainActor @ViewBuilder private var passphraseTabContent: some View {
    self.withBinding(
      \.configuration.passphraseGeneratorSettings.words,
      content: { (words: Binding<Int>) in
        Slider(
          "resource.edit.password.advanced.words.title",
          value: words,
          min: PassphraseGeneratorSettings.passphraseGenMinWords,
          max: PassphraseGeneratorSettings.passphraseGenMaxWords,
          onCommit: { self.controller.commitChange() }
        )
      }
    )

    self.with(\.configuration.passphraseGeneratorSettings.wordSeparator) { (separator: String) in
      let separatorBinding: Binding<Validated<String>> = Binding(
        get: { PassphraseGeneratorSettings.wordSeparatorValidator.validate(separator) },
        set: { (newValue: Validated<String>) in
          self.controller.setSeparator(newValue.value)
        }
      )
      FormTextFieldView(
        title: "resource.edit.password.advanced.separator.title",
        state: separatorBinding
      )
    }

    self.with(\.configuration.passphraseGeneratorSettings.wordCase) { (wordCase: PasswordGeneratorCase) in
      FormPickerFieldView<PasswordGeneratorCase>(
        title: "resource.edit.password.advanced.case.title",
        values: PasswordGeneratorCase.allCases,
        state: Validated.valid(wordCase),
        update: { (newCase: PasswordGeneratorCase) in
          self.controller.setWordCase(newCase)
        }
      )
    }
  }

  @MainActor @ViewBuilder private var saveButton: some View {
    self.with(\.saveEnabled) { (enabled: Bool) in
      PrimaryButton(
        title: "resource.edit.password.advanced.save.button.title",
        disabled: .constant(!enabled),
        action: self.controller.saveConfiguration
      )
    }
  }

  private static func navigationTitleKey(for generator: PasswordGeneratorType) -> DisplayableString {
    switch generator {
    case .password:
      return "resource.edit.password.advanced.title"
    case .passphrase:
      return "resource.edit.password.advanced.passphrase.title"
    }
  }

  private static func previewTitleKey(for generator: PasswordGeneratorType) -> DisplayableString {
    switch generator {
    case .password:
      return "resource.edit.password.advanced.preview.password.title"
    case .passphrase:
      return "resource.edit.password.advanced.preview.passphrase.title"
    }
  }

  @MainActor private func characterSetItems(
    for settings: PasswordGeneratorSettings
  ) -> Array<CharacterSetTagCloudView.Item> {
    [
      .init(
        id: "upper",
        label: "A-Z",
        isOn: settings.maskUpper,
        toggle: { self.controller.togglePasswordMask(\.maskUpper) }
      ),
      .init(
        id: "digit",
        label: "0-9",
        isOn: settings.maskDigit,
        toggle: { self.controller.togglePasswordMask(\.maskDigit) }
      ),
      .init(
        id: "lower",
        label: "a-z",
        isOn: settings.maskLower,
        toggle: { self.controller.togglePasswordMask(\.maskLower) }
      ),
      .init(
        id: "char1",
        label: "# $ % & @ ^ ~",
        isOn: settings.maskChar1,
        toggle: { self.controller.togglePasswordMask(\.maskChar1) }
      ),
      .init(
        id: "char2",
        label: ". , : ;",
        isOn: settings.maskChar2,
        toggle: { self.controller.togglePasswordMask(\.maskChar2) }
      ),
      .init(
        id: "parenthesis",
        label: "{ ( [ | ] ) }",
        isOn: settings.maskParenthesis,
        toggle: { self.controller.togglePasswordMask(\.maskParenthesis) }
      ),
      .init(
        id: "char3",
        label: "' \" `",
        isOn: settings.maskChar3,
        toggle: { self.controller.togglePasswordMask(\.maskChar3) }
      ),
      .init(
        id: "char5",
        label: "< * + ! ? =",
        isOn: settings.maskChar5,
        toggle: { self.controller.togglePasswordMask(\.maskChar5) }
      ),
      .init(
        id: "char4",
        label: "/ \\ _ -",
        isOn: settings.maskChar4,
        toggle: { self.controller.togglePasswordMask(\.maskChar4) }
      ),
      .init(
        id: "emoji",
        label: "😀",
        isOn: settings.maskEmoji,
        toggle: { self.controller.togglePasswordMask(\.maskEmoji) }
      ),
    ]
  }
}
