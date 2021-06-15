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

import Commons
import LocalAuthentication

public struct Biometrics {
  
  public var checkBiometricsPermission: () -> AnyPublisher<Bool, Never>
  public var requestBiometricsPermission: () -> AnyPublisher<Bool, TheError>
  public var supportedBiometryType: () -> BiometryType
}

extension Biometrics {
  
  public enum BiometryType {
    case none
    case touchID
    case faceID
  }
}

extension Biometrics {
  
  public static var live: Self {
    let context: LAContext = .init()
    
    func checkBiometricsPermission() -> AnyPublisher<Bool, Never> {
      var errorPtr: NSError?
      let result: Bool = context
        .canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &errorPtr
        )
      return Just(result && errorPtr == nil && context.biometryType != .none)
        .eraseToAnyPublisher()
    }
    
    func requestBiometricsPermission() -> AnyPublisher<Bool, TheError> {
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
        || laError.code == .passcodeNotSet {
        return Fail<Bool, TheError>(error: .biometricsUnavailable(underlyingError: laError))
          .eraseToAnyPublisher()
      } else {
        let completionSubject: PassthroughSubject<Bool, TheError> = .init()
        DispatchQueue.main.async {
          context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: NSLocalizedString("biometrics.usage.reason", comment: "")
          ) { granted, error in
            if error != nil {
              completionSubject.send(
                completion: .failure(.biometricsUnavailable(underlyingError: error))
              )
            } else {
              completionSubject.send(granted)
              completionSubject.send(completion: .finished)
            }
          }
        }
        return completionSubject
          .eraseToAnyPublisher()
      }
    }
    
    func supportedBiometryType() -> BiometryType {
      // we don't care the result, it is required to set valid `biometryType` by context
      _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
      
      switch context.biometryType {
      case .none:
        return .none
        
      case .touchID:
        return .touchID
        
      case .faceID:
        return .faceID
        
      @unknown default:
        assertionFailure("Unknown biometry type \(context.biometryType)")
        return .none
      }
    }
    
    return Self(
      checkBiometricsPermission: checkBiometricsPermission,
      requestBiometricsPermission: requestBiometricsPermission,
      supportedBiometryType: supportedBiometryType
    )
  }
}

#if DEBUG
extension Biometrics {
  
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      checkBiometricsPermission: Commons.placeholder("You have to provide mocks for used methods"),
      requestBiometricsPermission: Commons.placeholder("You have to provide mocks for used methods"),
      supportedBiometryType: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif

extension TheError {
  
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

extension TheError.ID {
  
  public static var biometricsUnavailable: Self { "biometricsUnavailable" }
}
