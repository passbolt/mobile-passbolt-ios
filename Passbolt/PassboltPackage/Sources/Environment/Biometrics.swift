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
import LocalAuthentication

public struct Biometrics: EnvironmentElement {

  public var checkBiometricsState: () -> State
  public var checkBiometricsPermission: () -> Bool
  public var requestBiometricsPermission: () -> AnyPublisher<Void, Error>
}

extension Biometrics {

  public enum State {

    case unavailable
    case unconfigured
    case configuredTouchID
    case configuredFaceID
  }
}

extension Biometrics {

  public static var live: Self {
    let context: LAContext = .init()

    func checkBiometricsState() -> State {
      var errorPtr: NSError?
      let result: Bool =
        context
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )

      if let laError: LAError = errorPtr as? LAError {
        switch laError.code {
        case .biometryNotAvailable:
          return .unavailable

        case .biometryNotEnrolled, .passcodeNotSet:
          return .unconfigured

        case _:
          return .unavailable
        }
      }
      else {
        switch (context.biometryType, result) {
        case (.none, _):
          return .unavailable

        case (_, false):
          return .unconfigured

        case (.faceID, true):
          return .configuredFaceID

        case (.touchID, true):
          return .configuredTouchID

        case (_, true):  // @unknown
          return .unavailable
        }
      }
    }

    func checkBiometricsPermission() -> Bool {
      var errorPtr: NSError?
      let result: Bool =
        context
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )
      return result && errorPtr == nil && context.biometryType != .none
    }

    func requestBiometricsPermission() -> AnyPublisher<Void, Error> {
      precondition(!isInExtensionContext, "Cannot request permission in app extension.")
      var errorPtr: NSError?
      context
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )
      if let laError: LAError = errorPtr as? LAError,
        laError.code == .biometryNotAvailable
          || laError.code == .biometryNotEnrolled
          || laError.code == .passcodeNotSet
      {
        return Fail(
          error:
            SystemFeaturePermissionNotGranted
            .error("Biometrics permission not granted")
            .recording(laError, for: "underlyingError")
        )
        .eraseToAnyPublisher()
      }
      else {
        let completionSubject: PassthroughSubject<Void, Error> = .init()
        DispatchQueue.main.async {
          context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: NSLocalizedString("biometrics.usage.reason", bundle: .localization, comment: "")
          ) { granted, error in
            if error == nil && granted {
              completionSubject.send()
              completionSubject.send(completion: .finished)
            }
            else {
              completionSubject.send(
                completion: .failure(
                  SystemFeaturePermissionNotGranted
                    .error("Biometrics permission not granted")
                    .recording(error as Any, for: "underlyingError")
                )
              )
            }
          }
        }
        return
          completionSubject
          .eraseToAnyPublisher()
      }
    }

    return Self(
      checkBiometricsState: checkBiometricsState,
      checkBiometricsPermission: checkBiometricsPermission,
      requestBiometricsPermission: requestBiometricsPermission
    )
  }
}

extension Environment {

  public var biometrics: Biometrics {
    get { element(Biometrics.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension Biometrics {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      checkBiometricsState: unimplemented("You have to provide mocks for used methods"),
      checkBiometricsPermission: unimplemented("You have to provide mocks for used methods"),
      requestBiometricsPermission: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif

extension TheErrorLegacy {

  public static func biometricsUnavailable(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .biometricsUnavailable,
      underlyingError: underlyingError,
      extensions: .init()
    )
  }
}

extension TheErrorLegacy.ID {

  public static var biometricsUnavailable: Self { "biometricsUnavailable" }
}
