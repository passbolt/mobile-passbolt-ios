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

import OSFeatures
import Resources

// MARK: - Implementation

extension OTPEditForm {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context,
    cancellables _: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(OTPEditScope.self)

    let nameFieldValidator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: "error.resource.field.empty",
        arguments: [
          DisplayableString.localized(
            key: "otp.edit.form.field.name.title"
          )
          .string()
        ]
      )
    )
    let uriFieldValidator: Validator<String> = .alwaysValid
    let secretFieldValidator: Validator<String> = .nonEmpty(
      displayable: .localized(
        key: "error.resource.field.empty",
        arguments: [
          DisplayableString.localized(
            key: "otp.edit.form.field.secret.title"
          )
          .string()
        ]
      )
    )
    let digitsFieldValidator: Validator<UInt> = .inRange(
      of: 6 ... 8,
      displayable: .localized(
        key: "error.resource.field.range.between",
        arguments: [
          DisplayableString.localized(
            key: "otp.edit.form.field.digits.title"
          )
          .string(),
          6,
          8,
        ]
      )
    )
    let periodFieldValidator: Validator<Seconds?> = Validator<Seconds>
      .inRange(
        of: 1 ... Seconds(rawValue: .max),
        displayable: .localized(
          key: "error.resource.field.range.greater",
          arguments: [
            DisplayableString.localized(
              key: "otp.edit.form.field.period.title"
            )
            .string(),
            0,
          ]
        )
      )
      .contraMapOptional()
    let counterFieldValidator: Validator<UInt64?> = .alwaysValid

    let updatesSource: UpdatesSequenceSource = .init()
    let formState: CriticalState<AutoValidated<State>> = .init(
      .init(
        state: .init(),
        .validating(\.name, with: nameFieldValidator),
        .validating(\.uri, with: uriFieldValidator),
        .validating(\.secret, with: secretFieldValidator),
        .validating(\.digits, with: digitsFieldValidator),
        .validating(\.type.period, with: periodFieldValidator),
        .validating(\.type.counter, with: counterFieldValidator),
        .validating(\.digits, with: digitsFieldValidator)
      )
    )

    @Sendable nonisolated func state() -> State {
      formState.get(\.state)
    }

    @Sendable nonisolated func fillFrom(
      uri: String
    ) throws {
      let configuration: OTPConfiguration = try parseTOTPConfiguration(from: uri)
      defer { updatesSource.sendUpdate() }
      try formState.access { (state: inout AutoValidated<State>) in
        state.apply(
          .assigning(
            State(
              name: .valid(configuration.account),
              uri: .valid(configuration.issuer ?? ""),
              secret: .valid(configuration.secret.sharedSecret),
              algorithm: .valid(configuration.secret.algorithm),
              digits: .valid(configuration.secret.digits),
              type: {
                switch configuration.secret {
                case .totp(_, _, _, let period):
                  return .totp(period: .valid(period))
                case .hotp(_, _, _, let counter):
                  return .hotp(counter: .valid(counter))
                }
              }()
            ),
            to: \.self
          )
        )
        try state.validate()
      }
    }

    @Sendable nonisolated func update(
      _ assignment: Assignment<State>
    ) {
      formState.access { (state: inout AutoValidated<State>) in
        state.apply(assignment)
      }
      updatesSource.sendUpdate()
    }

    @Sendable nonisolated func sendForm(
      _ action: SendFormAction
    ) async throws {
      let state: AutoValidated<State>
      do {
        state = try formState.access { (state: inout AutoValidated<State>) in
          try state.validate()
          return state
        }
      }
      catch {
        updatesSource.sendUpdate()
        throw error
      }

      let resourceEditingFeatures: Features =
        await features.branchIfNeeded(
          scope: ResourceEditScope.self,
          context: .create(
            {
              switch state.type {
              case .totp:
                return .totp
              case .hotp:
                return .hotp
              }
            }(),
            folderID: .none,
            uri: .none
          )
        ) ?? features

      let resourceEditForm: LegacyResourceEditForm = try await resourceEditingFeatures.instance()

      switch action {
      case .createStandalone:
        let resource: Resource = try await resourceEditForm.resource()

        guard
          let nameField: ResourceField = resource.fields.first(where: { $0.name == "name" }),
          let uriField: ResourceField = resource.fields.first(where: { $0.name == "uri" })
        else {
          throw InvalidResourceType.error()
        }

        try await resourceEditForm.setFieldValue(.string(state.name), nameField)
        try await resourceEditForm.setFieldValue(.string(state.uri), uriField)
        switch state.type {
        case .totp(let period):
          guard let totpField: ResourceField = resource.fields.first(where: { $0.name == "totp" })
          else { throw InvalidResourceType.error() }

          try await resourceEditForm
            .setFieldValue(
              .otp(
                .totp(
                  sharedSecret: state.secret,
                  algorithm: state.algorithm,
                  digits: state.digits,
                  period: period.value
                )
              ),
              totpField
            )

        case .hotp(let counter):
          guard let hotpField: ResourceField = resource.fields.first(where: { $0.name == "hotp" })
          else { throw InvalidResourceType.error() }

          try await resourceEditForm
            .setFieldValue(
              .otp(
                .hotp(
                  sharedSecret: state.secret,
                  algorithm: state.algorithm,
                  digits: state.digits,
                  counter: counter.value
                )
              ),
              hotpField
            )
        }

        _ = try await resourceEditForm.sendForm()

      case .attach(to: let resourceID):
        throw
          Unimplemented
          .error("[MOB-1094] Adding OTP to existing resource is not supported yet")
      }
    }

    return .init(
      updates: updatesSource.updatesSequence,
      state: state,
      fillFromURI: fillFrom(uri:),
      update: update(_:),
      sendForm: sendForm(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltOTPEditForm() {
    self.use(
      .lazyLoaded(
        OTPEditForm.self,
        load: OTPEditForm.load(features:context:cancellables:)
      ),
      in: OTPEditScope.self
    )
  }
}

private func parseTOTPConfiguration(
  from string: String
) throws -> OTPConfiguration {
  let string: String = string.removingPercentEncoding ?? string
  var reminder: Substring = string[string.startIndex ..< string.endIndex]

  // check and remove scheme substring
  let scheme: String = "otpauth://"
  guard let schemeRange: Range<Substring.Index> = reminder.range(of: scheme)
  else {
    throw
      InvalidOTPConfiguration
      .error("Invalid OTP configuration - invalid scheme")
  }
  reminder = reminder[schemeRange.upperBound ..< reminder.endIndex]

  // check and remove type substring
  // initially - supporting only TOTP
  let otpType: String = "totp/"
  guard let typeRange: Range<Substring.Index> = reminder.range(of: otpType)
  else {
    throw
      InvalidOTPConfiguration
      .error("Invalid OTP configuration - unsupported or missing type")
  }
  reminder = reminder[typeRange.upperBound ..< reminder.endIndex]

  // extract label
  let labelEndIndex: Substring.Index = reminder.firstIndex(of: "?") ?? reminder.endIndex
  let label: Substring = reminder[reminder.startIndex ..< labelEndIndex]

  // split label to issuer and account
  var issuer: String?
  let account: String
  if let splitIndex: Substring.Index = label.firstIndex(of: ":") {
    issuer = String(label[label.startIndex ..< splitIndex])
    account = String(label[label.index(after: splitIndex) ..< label.endIndex])
  }
  else {
    issuer = .none
    account = String(label)
  }

  // extract parameters
  let parameters: Array<(key: Substring, value: Substring)> = reminder[
    (reminder.index(labelEndIndex, offsetBy: 1, limitedBy: reminder.endIndex) ?? reminder.endIndex)
      ..< reminder.endIndex
  ]
  .split(separator: "&")
  .compactMap { (rawParameter: Substring) in
    let components: Array<Substring> =
      rawParameter
      .split(separator: "=")
    if  // only key/value pairs
    components.count == 2,
      let key: Substring = components.first,
      let value: Substring = components.last
    {
      return (
        key: key,
        value: value
      )
    }
    else {
      return .none
    }
  }

  guard
    let secret: String = parameters.first(where: { key, _ in key == "secret" }).map({ String($0.value) })
  else {
    throw
      InvalidOTPConfiguration
      .error("Invalid OTP configuration - missing secret")
  }

  let digits: UInt
  if let digitsParameter: UInt = parameters.first(where: { key, _ in key == "digits" }).flatMap({ UInt($0.value) }) {
    digits = digitsParameter
  }
  else {  // use default
    digits = 6
  }

  let algorithm: HOTPAlgorithm
  if let algorithmParameter: HOTPAlgorithm = parameters.first(where: { key, _ in key == "algorithm" })
    .flatMap({
      HOTPAlgorithm(rawValue: String($0.value))
    })
  {
    algorithm = algorithmParameter
  }
  else {  // use default
    algorithm = .sha1
  }

  let period: Seconds
  if let periodParameter: Int64 = parameters.first(where: { key, _ in key == "period" }).flatMap({ Int64($0.value) }) {
    period = .init(rawValue: periodParameter)
  }
  else {  // use default
    period = 30
  }

  if let issuerParameter: String = parameters.first(where: { key, _ in key == "issuer" }).flatMap({ String($0.value) })
  {
    guard issuer == nil || issuer == issuerParameter
    else {
      throw
        InvalidOTPConfiguration
        .error("Invalid OTP configuration - wrong scheme")
    }
    issuer = issuerParameter
  }  // else use whatever was in label

  return .init(
    issuer: issuer,
    account: account,
    secret: .totp(
      sharedSecret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period
    )
  )
}
