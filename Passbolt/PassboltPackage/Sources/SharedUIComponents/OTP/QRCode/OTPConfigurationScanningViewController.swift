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
import FeatureScopes
import OSFeatures
import Resources

public final class OTPConfigurationScanningViewController: ViewController {

  public struct Context {

    internal var totpPath: ResourceType.FieldPath

    public init(totpPath: ResourceType.FieldPath) {
      self.totpPath = totpPath
    }
  }

  public struct ViewState: Equatable {

    internal var loading: Bool
    internal var isStandaloneOTP: Bool
    internal var canEditManually: Bool
  }

  public nonisolated let viewState: ViewStateSource<ViewState>

  private let resourceEditForm: ResourceEditForm

  private let navigationToScanningSuccess: NavigationToOTPScanningSuccess
  private let navigationToSelf: NavigationToOTPScanning
  private let navigationToOTPEditForm: NavigationToOTPEditForm
  private let scanningState: CriticalState<ScanningState>

  private let context: Context

  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(ResourceEditScope.self)
    self.features = features.takeOwned()

    self.context = context

    self.navigationToScanningSuccess = try features.instance()
    self.navigationToSelf = try features.instance()
    self.navigationToOTPEditForm = try features.instance()
    self.scanningState = .init(.idle)

    self.resourceEditForm = try features.instance()
    let context: ResourceEditingContext = try features.context(of: ResourceEditScope.self)

    self.viewState = .init(
      initial: .init(
        loading: false,
        isStandaloneOTP: context.editedResource.type.specification.slug.isStandaloneTOTPType,
        canEditManually: context.editedResource.isLocal
          && context.editedResource.type.specification.slug.isStandaloneTOTPType
      )
    )
  }
}

extension OTPConfigurationScanningViewController {

  private enum ScanningState {
    case idle
    case processing
    case finished
  }

  @Sendable nonisolated internal func process(
    payload: String
  ) {
    guard self.scanningState.exchange(\.self, with: .processing, when: .idle)
    else { return }  // ignore when already processing
    do {
      let configuration: TOTPConfiguration = try parseTOTPConfiguration(from: payload)
      self.scanningState
        .exchange(
          \.self,
          with: .finished,
          when: .processing
        )
      Task { [viewState, context, resourceEditForm, navigationToSelf, navigationToScanningSuccess] in
        resourceEditForm.update(context.totpPath, to: configuration.secret)
        resourceEditForm.update(\.meta.uri, to: configuration.issuer)
        resourceEditForm.update(\.secret.totp, to: configuration.secret)
        if await viewState.current.isStandaloneOTP {
          resourceEditForm.update(\.nameField, to: configuration.account)
        }
        if try await resourceEditForm.state.value.isLocal {
          /// Only newly created standalone TOTP resources could be scanned  without edit form.
          if await viewState.current.isStandaloneOTP {
            try await navigationToScanningSuccess
              .perform(
                context: .init(
                  totpConfiguration: configuration
                )
              )
          }
          else {
            try await navigationToSelf.revert()
          }
        }
        else {
          await viewState
            .update(
              \.loading,
              to: true
            )
          do {
            try await navigationToSelf.revert()
          }
          catch {
            await viewState
              .update(
                \.loading,
                to: false
              )
            throw error
          }
        }
      }
    }
    catch is Cancelled {
      scanningState
        .exchange(
          \.self,
          with: .idle,
          when: .processing
        )
    }
    catch {
      scanningState
        .exchange(
          \.self,
          with: .idle,
          when: .processing
        )

      error.consume()
    }
  }

  /// Navigate to manual TOTP configuration editing form.
  internal func editManually() async {
    await consumingErrors {
      try await self.navigationToOTPEditForm.perform(
        context: .init(
          totpPath: context.totpPath
        )
      )
    }
  }
}

private func parseTOTPConfiguration(
  from string: String
) throws -> TOTPConfiguration {
  let string: String =
    string
    .replacingOccurrences(of: "+", with: " ")
    .removingPercentEncoding
    ?? string
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
  var issuer: String
  var account: String
  if let splitIndex: Substring.Index = label.firstIndex(of: ":") {
    issuer = String(label[label.startIndex ..< splitIndex])
    account = String(label[label.index(after: splitIndex) ..< label.endIndex])
  }
  else {
    issuer = ""
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

  let issuerParameter: String? =
    parameters
    .first(where: { key, _ in key == "issuer" })
    .flatMap({ String($0.value) })?
    .trimmingCharacters(in: .whitespaces)
  if let issuerParameter, issuerParameter.isEmpty == false {
    if issuer != issuerParameter, issuer.isEmpty == false {
      account = "\(issuer):\(account)"
    }
    issuer = issuerParameter
  }  // else use whatever was in label

  return .init(
    issuer: issuer,
    account: account,
    secret: .init(
      sharedSecret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period
    )
  )
}
