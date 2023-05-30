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

internal final class TOTPEditAdvancedFormController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let resourceEditForm: ResourceEditForm

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.resourceEditForm = try features.instance()

    self.viewState = .init(
      initial: .init(
        algorithm: .valid(.sha1),
        period: .valid("30"),
        digits: .valid("6"),
        snackBarMessage: .none
      )
    )

    self.asyncExecutor
      .scheduleIteration(
        over: self.resourceEditForm.state,
        catchingWith: self.diagnostics,
        failMessage: "Resource form updates broken!",
        failAction: { [viewState] (error: Error) in
          viewState.update { state in
            state.snackBarMessage = .error(error)
          }
        }
      ) { [viewState] (resource: Resource) in
        let resourceSecret: JSON = resource.secret

        // searching only for "totp" field, can't identify totp otherwise now
        let algorithm: HOTPAlgorithm =
          resourceSecret.totp.algorithm.stringValue.flatMap(
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
  }
}

extension TOTPEditAdvancedFormController {

  internal struct ViewState: Equatable {

    internal var algorithm: Validated<HOTPAlgorithm>
    internal var period: Validated<String>
    internal var digits: Validated<String>
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension TOTPEditAdvancedFormController {

  internal final func setAlgorithm(
    _ algorithm: HOTPAlgorithm
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.algorithm = .valid(algorithm)
    }
    self.asyncExecutor
      .scheduleCatchingWith(self.diagnostics, behavior: .replace) { [viewState, resourceEditForm] in
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

  internal final func setPeriod(
    _ period: String
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.period = .valid(period)
    }
    self.asyncExecutor
      .scheduleCatchingWith(self.diagnostics, behavior: .replace) { [viewState, resourceEditForm] in
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

  internal final func setDigits(
    _ digits: String
  ) {
    self.viewState.update { (state: inout ViewState) in
      state.digits = .valid(digits)
    }
    self.asyncExecutor
      .scheduleCatchingWith(self.diagnostics, behavior: .replace) { [viewState, resourceEditForm] in
        try Task.checkCancellation()
        let validated: Validated<String> =
          try await resourceEditForm
          .update(
            \.secret.totp.digits,
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
}
