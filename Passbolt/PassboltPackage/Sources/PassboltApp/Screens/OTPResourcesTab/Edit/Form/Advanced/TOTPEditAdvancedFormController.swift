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

internal struct TOTPEditAdvancedFormController {

  internal var viewState: MutableViewState<ViewState>

  internal var setAlgorithm: @MainActor (HOTPAlgorithm) -> Void
  internal var setPeriod: @MainActor (String) -> Void
  internal var setDigits: @MainActor (String) -> Void
}

extension TOTPEditAdvancedFormController: ViewController {

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
      setDigits: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension TOTPEditAdvancedFormController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let resourceEditForm: ResourceEditForm = try features.instance()

    let totpProxy: MutableState<ResourceTOTPFieldProxy> = .init {
      let resource: Resource = try await resourceEditForm.state.value

      guard let totpField: ResourceField = resource.fields.first(where: { $0.name == "totp" })
      else { throw InvalidResourceType.error() }
      let totpFieldPath: ResourceField.ValuePath = totpField.valuePath

      return try await resourceEditForm.updatableTOTPField(totpFieldPath)
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
      do {
        let totpSecret: TOTPSecret = try await totpProxy.value.rawValue
        await viewState.update { state in
          state = .init(
            algorithm: .valid(totpSecret.algorithm),
            period: .valid("\(totpSecret.period.rawValue)"),
            digits: .valid("\(totpSecret.digits)"),
            snackBarMessage: .none
          )
        }
      }
      catch {
        diagnostics.log(error: error)
        await viewState.update { state in
          state.snackBarMessage = .error(error)
        }
      }
    }

    @MainActor func setAlgorithm(
      _ algorithm: HOTPAlgorithm
    ) {
      viewState.update { (state: inout ViewState) in
        state.algorithm = .valid(algorithm)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          let validated = try await totpProxy.value.update(\.algorithm, to: algorithm)
          await viewState.update { (state: inout ViewState) in
            state.algorithm = validated
          }
        }
    }

    @MainActor func setPeriod(
      _ period: String
    ) {
      guard let periodValue: Int64 = .init(period)
      else {
        return viewState.update { (state: inout ViewState) in
          state.period = .invalid(
            period,
            error: InvalidValue.invalid(
              value: period,
              displayable: "error.resource.field.characters.invalid"
            )
          )
        }
      }
      viewState.update { (state: inout ViewState) in
        state.period = .valid(period)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          let validated = try await totpProxy.value.update(\.period, to: .init(rawValue: periodValue))
          await viewState.update { (state: inout ViewState) in
            state.period = validated.map { _ in period }
          }
        }
    }

    @MainActor func setDigits(
      _ digits: String
    ) {
      guard let digitsValue: UInt = .init(digits)
      else {
        return viewState.update { (state: inout ViewState) in
          state.digits = .invalid(
            digits,
            error: InvalidValue.invalid(
              value: digits,
              displayable: "error.resource.field.characters.invalid"
            )
          )
        }
      }
      viewState.update { (state: inout ViewState) in
        state.digits = .valid(digits)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          let validated = try await totpProxy.value.update(\.digits, to: digitsValue)
          await viewState.update { (state: inout ViewState) in
            state.digits = validated.map { _ in digits }
          }
        }
    }

    return .init(
      viewState: viewState,
      setAlgorithm: setAlgorithm(_:),
      setPeriod: setPeriod(_:),
      setDigits: setDigits(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveTOTPEditAdvancedFormController() {
    self.use(
      .disposable(
        TOTPEditAdvancedFormController.self,
        load: TOTPEditAdvancedFormController.load(features:)
      ),
      in: ResourceEditScope.self
    )
  }
}
