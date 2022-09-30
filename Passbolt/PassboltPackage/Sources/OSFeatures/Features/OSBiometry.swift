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

import Features
import LocalAuthentication

// MARK: - Interface

public struct OSBiometry {

  public var availability: @Sendable () -> Availability
  public var requestPermission: @Sendable () async throws -> Void
}

extension OSBiometry {

  public enum Availability {

    case unavailable
    case unconfigured
    case touchID
    case faceID
  }
}

extension OSBiometry: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      availability: unimplemented(),
      requestPermission: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSBiometry {

  fileprivate static var live: Self {
    @Sendable func availability() -> Availability {
      let laContext: LAContext = .init()

      var errorPtr: NSError?
      let result: Bool =
        laContext
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )

      if let laError: LAError = errorPtr as? LAError {
        switch laError.code {
        case .biometryNotEnrolled, .passcodeNotSet:
          return .unconfigured

        case .biometryNotAvailable:
          return .unavailable

        case _:
          return .unavailable
        }
      }
      else {
        switch (laContext.biometryType, result) {
        case (.faceID, true):
          return .faceID

        case (.touchID, true):
          return .touchID

        case (_, false):
          return .unconfigured

        case (.none, _), (_, true):
          return .unavailable
        }
      }
    }

    @Sendable func requestPermission() async throws {
      guard !isInExtensionContext
      else {
        throw
          SystemFeatureUnavailable
          .error(
            underlyingError:
              Unavailable
              .error("Cannot request permission in app extension.")
          )
      }

      let laContext: LAContext = .init()
      var errorPtr: NSError?
      laContext
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )
      if let laError: LAError = errorPtr as? LAError,
        laError.code == .biometryNotAvailable
          || laError.code == .biometryNotEnrolled
          || laError.code == .passcodeNotSet
      {
        throw
          SystemFeaturePermissionNotGranted
          .error("Biometrics permission not granted")
          .recording(laError, for: "underlyingError")
      }
      else {
        try await Task { @MainActor in
          try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            laContext.evaluatePolicy(
              .deviceOwnerAuthenticationWithBiometrics,
              localizedReason:
                DisplayableString
                .localized("biometrics.usage.reason")
                .string()
            ) { (granted: Bool, error: Error?) in
              if error == nil && granted {
                continuation.resume(returning: Void())
              }
              else {
                continuation.resume(
                  throwing:
                    SystemFeaturePermissionNotGranted
                    .error("Biometrics permission not granted")
                    .recording(error as Any, for: "underlyingError")
                )
              }
            }
          }
        }
        .value
      }
    }

    return Self(
      availability: availability,
      requestPermission: requestPermission
    )
  }
}

extension FeatureFactory {

  internal func useOSBiometry() {
    self.use(
      OSBiometry.live
    )
  }
}
