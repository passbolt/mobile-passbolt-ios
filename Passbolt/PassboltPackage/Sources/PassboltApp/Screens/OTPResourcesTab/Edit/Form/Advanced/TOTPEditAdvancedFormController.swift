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
        let resourceSecret: JSON = try await resourceEditForm.state.value.secret

        // searching only for "totp" field, can't identify totp otherwise now
        let algorithm: HOTPAlgorithm = resourceSecret.totp.algorithm.stringValue.flatMap(
          HOTPAlgorithm.init(rawValue:)
        ) ?? .sha1
        let digits: Int = resourceSecret.totp.digits.intValue ?? 6
        let period: Int = resourceSecret.totp.period.intValue ?? 30

        await viewState.update { state in
          state = .init(
            algorithm: .valid(algorithm),
            period: .valid("\(period)"),
            digits: .valid("\(digits)"),
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
          try Task.checkCancellation()
          let validated: Validated<HOTPAlgorithm> =
            try await resourceEditForm
            .update(
              \.secret.totp.algorithm,
              to: algorithm,
              valueToJSON: { (value: HOTPAlgorithm) -> JSON in
                .string(value.rawValue)
              },
              jsonToValue: { (json: JSON) -> HOTPAlgorithm in
                if let string: String = json.stringValue,
                  let algorithm: HOTPAlgorithm = .init(rawValue: string)
                {
                  return algorithm
                }
                else {
                  throw InvalidValue.invalid(
                    value: algorithm,
                    displayable: "TODO: FIXME: invalid selection"
                  )
                }
              }
            )
          try Task.checkCancellation()
          await viewState.update { (state: inout ViewState) in
            state.algorithm = validated
          }
        }
    }

    @MainActor func setPeriod(
      _ period: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.period = .valid(period)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          try Task.checkCancellation()
          let validated: Validated<String> =
            try await resourceEditForm
            .update(
              \.secret.totp.period,
              to: period,
              valueToJSON: { (value: String) -> JSON in
                guard let periodValue: Int = .init(period)
                else {
                  throw InvalidValue.invalid(
                    value: period,
                    displayable: "error.resource.field.characters.invalid"
                  )
                }
                return .integer(periodValue)
              },
              jsonToValue: { (json: JSON) -> String in
                if let int: Int = json.intValue {
                  return "\(int)"
                }
                else {
                  throw InvalidValue.invalid(
                    value: json,
                    displayable: "TODO: FIXME: invalid value"
                  )
                }
              }
            )
          try Task.checkCancellation()
          await viewState.update { (state: inout ViewState) in
            state.period = validated
          }
        }
    }

    @MainActor func setDigits(
      _ digits: String
    ) {
      viewState.update { (state: inout ViewState) in
        state.digits = .valid(digits)
      }
      asyncExecutor
        .scheduleCatchingWith(diagnostics, behavior: .replace) {
          try Task.checkCancellation()
          let validated: Validated<String> =
            try await resourceEditForm
            .update(
              \.secret.totp.period,
              to: digits,
              valueToJSON: { (value: String) -> JSON in
                guard let digitsValue: Int = .init(digits)
                else {
                  throw InvalidValue.invalid(
                    value: digits,
                    displayable: "error.resource.field.characters.invalid"
                  )
                }
                return .integer(digitsValue)
              },
              jsonToValue: { (json: JSON) -> String in
                if let int: Int = json.intValue {
                  return "\(int)"
                }
                else {
                  throw InvalidValue.invalid(
                    value: json,
                    displayable: "TODO: FIXME: invalid value"
                  )
                }
              }
            )
          try Task.checkCancellation()
          await viewState.update { (state: inout ViewState) in
            state.digits = validated
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
