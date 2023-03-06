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
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()

    #warning("[MOB-1093] TODO: FIXME: complete OTP edit form")

    let updatesSource: UpdatesSequenceSource = .init()
    let currentState: CriticalState<State> = .init(
      .init(
        issuer: .none,
        account: "",
        secret: "",
        digits: 6,
        algorithm: .sha1,
        period: 30
      )
    )

    @Sendable nonisolated func state() -> State {
      currentState.get(\.self)
    }

    @Sendable nonisolated func fillFrom(
      uri: String
    ) throws {
      let configuration: TOTPConfiguration = try parseTOTPConfiguration(from: uri)

      currentState.set(\.self, configuration)
    }

    return .init(
      updates: updatesSource.updatesSequence,
      state: state,
      fillFromURI: fillFrom(uri:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltOTPEditForm() {
    self.use(
      .disposable(
        OTPEditForm.self,
        load: OTPEditForm.load(features:)
      ),
      in: OTPEditScope.self
    )
  }
}

private func parseTOTPConfiguration(
  from string: String
) throws -> TOTPConfiguration {
  let string: String = string.removingPercentEncoding ?? string
  var reminder: Substring = string[string.startIndex..<string.endIndex]

  // check and remove scheme substring
  let scheme: String = "otpauth://"
  guard let schemeRange: Range<Substring.Index> = reminder.range(of: scheme)
  else {
    throw
      InvalidOTPConfiguration
      .error("Invalid OTP configuration - invalid scheme")
  }
  reminder = reminder[schemeRange.upperBound..<reminder.endIndex]

  // check and remove type substring
  let otpType: String = "totp/"
  guard let typeRange: Range<Substring.Index> = reminder.range(of: otpType)
  else {
    throw
      InvalidOTPConfiguration
      .error("Invalid OTP configuration - unsupported or missing type")
  }
  reminder = reminder[typeRange.upperBound..<reminder.endIndex]

  // extract label
  let labelEndIndex: Substring.Index = reminder.firstIndex(of: "?") ?? reminder.endIndex
  let label: Substring = reminder[reminder.startIndex..<labelEndIndex]

  // split label to issuer and account
  var issuer: String?
  let account: String
  if let splitIndex: Substring.Index = label.firstIndex(of: ":") {
    issuer = String(label[label.startIndex..<splitIndex])
    account = String(label[label.index(after: splitIndex)..<label.endIndex])
  }
  else {
    issuer = .none
    account = String(label)
  }

  // extract parameters
  let parameters: Array<(key: Substring, value: Substring)> = reminder[
    (reminder.index(labelEndIndex, offsetBy: 1, limitedBy: reminder.endIndex) ?? reminder.endIndex)..<reminder.endIndex
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
  if let algorithmParameter: HOTPAlgorithm = parameters.first(where: { key, _ in key == "algorithm" }).flatMap({
    HOTPAlgorithm(rawValue: String($0.value))
  }) {
    algorithm = algorithmParameter
  }
  else {  // use default
    algorithm = .sha1
  }

  let period: Seconds
  if let periodParameter: UInt64 = parameters.first(where: { key, _ in key == "period" }).flatMap({ UInt64($0.value) })
  {
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
    secret: secret,
    digits: digits,
    algorithm: algorithm,
    period: period
  )
}
