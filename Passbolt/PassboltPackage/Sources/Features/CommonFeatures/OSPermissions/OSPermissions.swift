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
import Environment

public struct OSPermissions {
  /// Ensure app has permission to use the camera
  /// In application context asks for permission if needed.
  /// In extension context verifies permission status.
  /// - Returns: A publisher which emits a boolean indicating wether
  /// the permission has been granted or not.
  public var ensureCameraPermission: () -> AnyPublisher<Void, Error>
  public var ensureBiometricsPermission: () -> AnyPublisher<Void, Error>
}

extension OSPermissions: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let camera: Camera = environment.camera
    let biometrics: Biometrics = environment.biometrics

    nonisolated func ensureCameraPermission() -> AnyPublisher<Void, Error> {
      camera.checkPermission()
        .map { status -> AnyPublisher<Void, Error> in
          switch status {
          case .notDetermined:
            if isInExtensionContext {
              return Fail(
                error:
                  SystemFeaturePermissionNotGranted
                  .error("Camera is inaccessible in app extension context")
              )
              .eraseToAnyPublisher()
            }
            else {
              return camera.requestPermission().eraseToAnyPublisher()
            }

          case .denied:
            return Fail(
              error:
                SystemFeaturePermissionNotGranted
                .error("Camera permission not granted")
            )
            .eraseToAnyPublisher()

          case .authorized:
            return Just(Void())
              .eraseErrorType()
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    nonisolated func ensureBiometricsPermission() -> AnyPublisher<Void, Error> {
      biometrics
        .requestBiometricsPermission()
        .eraseToAnyPublisher()
    }

    return Self(
      ensureCameraPermission: ensureCameraPermission,
      ensureBiometricsPermission: ensureBiometricsPermission
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      ensureCameraPermission: unimplemented("You have to provide mocks for used methods"),
      ensureBiometricsPermission: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
