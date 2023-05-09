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

internal struct OTPConfigurationScanningController {

  internal var viewState: MutableViewState<ViewState>

  internal var processPayload: @Sendable (String) -> Void
}

extension OTPConfigurationScanningController: ViewController {

  internal struct ViewState: Equatable {

    internal var loading: Bool
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      processPayload: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension OTPConfigurationScanningController {

  private enum ScanningState {
    case idle
    case processing
    case finished
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToScanningSuccess: NavigationToOTPScanningSuccess = try features.instance()
    let navigationToSelf: NavigationToOTPScanning = try features.instance()

    let scanningState: CriticalState<ScanningState> = .init(.idle)

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        loading: false,
        snackBarMessage: .info(
          .localized(
            key: "otp.create.code.scanning.initial.message"
          )
        )
      )
    )

    @Sendable nonisolated func process(
      payload: String
    ) {
      guard scanningState.exchange(\.self, with: .processing, when: .idle)
      else { return }  // ignore when already processing
      do {
        let configuration: TOTPConfiguration = try parseTOTPConfiguration(from: payload)
        scanningState
          .exchange(
            \.self,
            with: .finished,
            when: .processing
          )
        asyncExecutor.scheduleCatching(
          with: diagnostics,
          behavior: .reuse,
          identifier: #function
        ) {
          if features.checkScope(ResourceEditScope.self) {
            await viewState
              .update(
                \.loading,
                to: true
              )
            do {
              let resourceEditForm: ResourceEditForm = try await features.instance()
              try await resourceEditForm.update(
                ResourceField.valuePath(forName: "totp"),
                to: .totp(configuration.secret)
              )
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
          else {
            try await navigationToScanningSuccess.perform(context: configuration)
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
        diagnostics.log(error: error)
        asyncExecutor.schedule(.reuse, identifier: #function) {
          await viewState
            .update(
              \.snackBarMessage,
              to: .error(error)
            )
        }
      }
    }

    return .init(
      viewState: viewState,
      processPayload: process(payload:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveOTPScanningController() {
    self.use(
      .disposable(
        OTPConfigurationScanningController.self,
        load: OTPConfigurationScanningController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
private func parseTOTPConfiguration(
  from string: String
) throws -> TOTPConfiguration {
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
  var issuer: String
  let account: String
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

  if let issuerParameter: String = parameters.first(where: { key, _ in key == "issuer" }).flatMap({ String($0.value) })
  {
    guard issuer.isEmpty || issuer == issuerParameter
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
    secret: .init(
      sharedSecret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period
    )
  )
}
