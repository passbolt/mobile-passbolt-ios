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
import Crypto
import Display

@MainActor
internal final class AdvancedPasswordGenerationViewController: ViewController {

  internal struct Context {
    internal let onSaveGenerated: @Sendable (String) async -> Void

    internal init(
      onSaveGenerated: @escaping @Sendable (String) async -> Void
    ) {
      self.onSaveGenerated = onSaveGenerated
    }
  }

  internal struct ViewState: Equatable {
    internal var configuration: PasswordPoliciesDSV
    internal var preview: String
    internal var saveEnabled: Bool
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  private let onSaveGenerated: @Sendable (String) async -> Void
  private let passwordService: PasswordService
  private let secretGenerator: SecretGenerator
  private let navigationToSelf: NavigationToAdvancedPasswordGeneration

  internal init(context: Context, features: Features) throws {
    self.onSaveGenerated = context.onSaveGenerated
    let passwordService: PasswordService = try features.instance()
    let secretGenerator: SecretGenerator = try features.instance()
    self.passwordService = passwordService
    self.secretGenerator = secretGenerator
    self.navigationToSelf = try features.instance()

    self.viewState = .init(
      initial: .init(
        configuration: .default,
        preview: "",
        saveEnabled: false
      ),
      updateFrom: passwordService.configuration(),
      update: {
        @MainActor [secretGenerator] (updateState, update: Update<PasswordPoliciesDSV>) async throws -> Void in
        let configuration: PasswordPoliciesDSV = try update.value
        updateState { (state: inout ViewState) in
          state.configuration = configuration
          Self.regeneratePreview(into: &state, using: secretGenerator)
        }
      }
    )
  }
}

extension AdvancedPasswordGenerationViewController {

  internal func selectTab(_ generator: PasswordGeneratorType) {
    self.applyChange { (state: inout ViewState) -> Bool in
      guard state.configuration.defaultGenerator != generator else { return false }
      state.configuration.defaultGenerator = generator
      return true
    }
  }

  internal func togglePasswordMask(
    _ keyPath: WritableKeyPath<PasswordGeneratorSettings, Bool>
  ) {
    self.applyChange { (state: inout ViewState) -> Bool in
      let currentlyOn: Bool = state.configuration.passwordGeneratorSettings[keyPath: keyPath]
      if currentlyOn {
        let enabledCount: Int = Self.enabledMaskCount(state.configuration.passwordGeneratorSettings)
        guard enabledCount > 1 else { return false }
        state.configuration.passwordGeneratorSettings[keyPath: keyPath] = false
      }
      else {
        state.configuration.passwordGeneratorSettings[keyPath: keyPath] = true
      }
      return true
    }
  }

  internal func setWordCase(_ wordCase: PasswordGeneratorCase) {
    self.applyChange { (state: inout ViewState) -> Bool in
      guard state.configuration.passphraseGeneratorSettings.wordCase != wordCase else { return false }
      state.configuration.passphraseGeneratorSettings.wordCase = wordCase
      return true
    }
  }

  internal func setSeparator(_ separator: String) {
    self.applyChange { (state: inout ViewState) -> Bool in
      guard state.configuration.passphraseGeneratorSettings.wordSeparator != separator else { return false }
      state.configuration.passphraseGeneratorSettings.wordSeparator = separator
      return true
    }
  }

  internal func setExcludeLookAlikeChars(_ excluded: Bool) {
    self.applyChange { (state: inout ViewState) -> Bool in
      guard state.configuration.passwordGeneratorSettings.excludeLookAlikeChars != excluded else { return false }
      state.configuration.passwordGeneratorSettings.excludeLookAlikeChars = excluded
      return true
    }
  }

  /// Called on slider commit (drag end or text field commit). The binding already mutated
  /// the configuration on each tick; here we regenerate the preview atomically.
  internal func commitChange() {
    self.applyChange { _ in true }
  }

  internal func saveConfiguration() async {
    let snapshot: ViewState = self.stateSnapshot
    guard !snapshot.preview.isEmpty else { return }
    await consumingErrors {
      await self.passwordService.updateConfiguration(snapshot.configuration)
      await self.onSaveGenerated(snapshot.preview)
      try await self.navigationToSelf.revert()
    }
  }
}

extension AdvancedPasswordGenerationViewController {

  /// Current view state, read without consulting the update source.
  ///
  /// `viewState.current` would run the source update closure and regenerate the preview, committing a
  /// secret other than the one shown to the user. Reading through `update` touches only the local value,
  /// and the unchanged state is filtered out downstream by `removeDuplicates`.
  internal var stateSnapshot: ViewState {
    self.viewState.update { (state: inout ViewState) -> ViewState in state }
  }

  /// Atomically apply a state mutation and regenerate the preview in a single ViewState update,
  /// so subscribers never observe a configuration/preview mismatch.
  private func applyChange(_ mutation: @MainActor (inout ViewState) -> Bool) {
    let secretGenerator: SecretGenerator = self.secretGenerator
    self.viewState.update { (state: inout ViewState) in
      guard mutation(&state) else { return }
      Self.regeneratePreview(into: &state, using: secretGenerator)
    }
  }

  private static func regeneratePreview(
    into state: inout ViewState,
    using secretGenerator: SecretGenerator
  ) {
    let valid: Bool = Self.isConfigurationValid(state.configuration)
    do {
      state.preview = try secretGenerator.generate(state.configuration)
      state.saveEnabled = valid
    }
    catch {
      state.preview = ""
      state.saveEnabled = false
    }
  }

  private static func enabledMaskCount(_ settings: PasswordGeneratorSettings) -> Int {
    let masks: Array<Bool> = [
      settings.maskUpper,
      settings.maskLower,
      settings.maskDigit,
      settings.maskParenthesis,
      settings.maskEmoji,
      settings.maskChar1,
      settings.maskChar2,
      settings.maskChar3,
      settings.maskChar4,
      settings.maskChar5,
    ]
    return masks.filter { $0 }.count
  }

  private static func isConfigurationValid(_ configuration: PasswordPoliciesDSV) -> Bool {
    switch configuration.defaultGenerator {
    case .password:
      do {
        try configuration.passwordGeneratorSettings.maskValidator
          .ensureValid(configuration.passwordGeneratorSettings)
        return true
      }
      catch {
        return false
      }
    case .passphrase:
      do {
        try PassphraseGeneratorSettings.wordsValidator
          .ensureValid(configuration.passphraseGeneratorSettings.words)
        try PassphraseGeneratorSettings.wordSeparatorValidator
          .ensureValid(configuration.passphraseGeneratorSettings.wordSeparator)
        return true
      }
      catch {
        return false
      }
    }
  }
}
