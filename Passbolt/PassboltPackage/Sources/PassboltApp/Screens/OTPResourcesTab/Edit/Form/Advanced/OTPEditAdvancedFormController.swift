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
import OSFeatures
import Resources

// MARK: - Interface

internal struct OTPEditAdvancedFormController {

  internal var viewState: MutableViewState<ViewState>

  internal var setAlgorithm: @MainActor (HOTPAlgorithm) -> Void
  internal var setPeriod: @MainActor (String) -> Void
  internal var setDigits: @MainActor (String) -> Void
  internal var applyChanges: @MainActor () -> Void
}

extension OTPEditAdvancedFormController: ViewController {

  internal struct ViewState: Equatable {

    internal var algorithm: Validated<HOTPAlgorithm>
    internal var period: Validated<String>
    internal var digits: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }

#if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      setAlgorithm: unimplemented1(),
      setPeriod: unimplemented1(),
      setDigits: unimplemented1(),
      applyChanges: unimplemented0()
    )
  }
#endif
}

// MARK: - Implementation

extension OTPEditAdvancedFormController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(OTPEditScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToSelf: NavigationToOTPEditAdvancedForm = try features.instance()

    let otpEditForm: OTPEditForm = try features.instance()

    let digitsFieldValidator: Validator<String> = .init { (string: String) -> Validated<String> in
      guard !string.isEmpty
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: string,
              displayable: .localized(
                key: "error.resource.field.empty",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.digits.title"
                  ).string()
                ]
              )
            )
          )
      }
      guard let digits: UInt = UInt(string)
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: string,
              displayable: .localized(
                key: "error.resource.field.characters.invalid",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.digits.title"
                  ).string()
                ]
              )
            )
        )
      }

      guard (6 ... 8).contains(digits)
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: digits,
              displayable: .localized(
                key: "error.resource.field.range.between",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.digits.title"
                  ).string(),
                  6,
                  8,
                ]
              )
            )
        )
      }

      return .valid(string)
    }
    let periodFieldValidator: Validator<String> = .init { (string: String) -> Validated<String> in
      guard !string.isEmpty
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: string,
              displayable: .localized(
                key: "error.resource.field.empty",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.period.title"
                  ).string()
                ]
              )
            )
          )
      }
      guard let digits: Int64 = Int64(string)
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: string,
              displayable: .localized(
                key: "error.resource.field.characters.invalid",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.period.title"
                  ).string()
                ]
              )
            )
        )
      }

      guard digits > 0
      else {
        return .invalid(
          string,
          error: InvalidValue
            .invalid(
              value: digits,
              displayable: .localized(
                key: "error.resource.field.range.greater",
                arguments: [
                  DisplayableString.localized(
                    key: "otp.edit.form.field.period.title"
                  ).string(),
                  0,
                ]
              )
            )
        )
      }

      return .valid(string)
    }

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        algorithm: .valid(.sha1),
        period: .valid("30"),
        digits: .valid("6"),
        snackBarMessage: .none
      )
    )

    asyncExecutor.schedule {
      await viewState.update { (state: inout ViewState) in
        let initialState: OTPEditForm.State = otpEditForm.state()
        state.algorithm = initialState.algorithm
        state.period = initialState.type.period.map { "\($0 ?? 0)" }
        state.digits = initialState.digits.map { "\($0)" }
      }
      for await _ in otpEditForm.updates.dropFirst() {
        let updatedState: OTPEditForm.State = otpEditForm.state()
        await viewState.update { (state: inout ViewState) in
          state.algorithm = updatedState.algorithm
          state.period = updatedState.type.period.map { "\($0 ?? 0)" }
          state.digits = updatedState.digits.map { "\($0)" }
        }
      }
    }

    @MainActor func setAlgorithm(
      _ algorithm: HOTPAlgorithm
    ) {
      viewState.update { (state: inout ViewState) in
        state.algorithm = .valid(algorithm)
      }
    }

    @MainActor func setPeriod(
      _ period: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.period = periodFieldValidator.validate(period)
      }
    }

    @MainActor func setDigits(
      _ digits: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.digits = digitsFieldValidator.validate(digits)
      }
    }

    nonisolated func applyChanges() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        behavior: .reuse
      ) { @MainActor in
        do {
          let state: ViewState = viewState.value

          otpEditForm
            .update(
              field: \.algorithm,
              toValidated: state.algorithm.value
            )

          if let digitsError: Error = state.digits.error {
            throw digitsError
          }
          else if let digits: UInt = UInt(state.digits.value) {
            otpEditForm
              .update(
                field: \.digits,
                toValidated: digits
              )
          }
          else {
            let error: InvalidValue = .invalid(
                value: state.digits.value,
                displayable: .localized(
                  key: "error.resource.field.characters.invalid",
                  arguments: [
                    DisplayableString.localized(
                      key: "otp.edit.form.field.digits.title"
                    ).string()
                  ]
                )
              )
            viewState.update(
              \.digits,
               to: .invalid(
                state.digits.value,
                error: error
               )
            )
            throw error
          }

          if let periodError: Error = state.period.error {
            throw periodError
          }
          else if let period: Seconds = Int64(state.period.value).map(Seconds.init(rawValue:)) {
            otpEditForm
              .update(
                field: \.type.period,
                toValidated: period
              )
          }
          else {
            let error: InvalidValue = .invalid(
                value: state.period.value,
                displayable: .localized(
                  key: "error.resource.field.characters.invalid",
                  arguments: [
                    DisplayableString.localized(
                      key: "otp.edit.form.field.period.title"
                    ).string()
                  ]
                )
              )
            viewState.update(
              \.period,
               to: .invalid(
                state.period.value,
                error: error
               )
            )
            throw error
          }

          try await navigationToSelf.revert()
        }
        catch {
          viewState
            .update(
              \.snackBarMessage,
               to: .error(error)
            )
          throw error
        }
      }
    }

    return .init(
      viewState: viewState,
      setAlgorithm: setAlgorithm(_:),
      setPeriod: setPeriod(_:),
      setDigits: setDigits(_:),
      applyChanges: applyChanges
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPEditAdvancedFormController() {
    self.use(
      .disposable(
        OTPEditAdvancedFormController.self,
        load: OTPEditAdvancedFormController.load(features:)
      ),
      in: OTPEditScope.self
    )
  }
}
