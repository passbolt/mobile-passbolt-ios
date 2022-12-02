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

import class AVFoundation.AVCaptureDevice
import enum AVFoundation.AVAuthorizationStatus
import CommonModels

// MARK: - Interface

public struct OSCamera {

  public var ensurePermission: () async throws -> Void
}

extension OSCamera: StaticFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      ensurePermission: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSCamera {

  fileprivate static var live: Self {

    @MainActor func ensurePermission() async throws {
      guard isInApplicationContext
      else {
        throw
          Unavailable
          .error("Camera is inaccessible outside of application context")
      }
      let authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

      switch authorizationStatus {
      case .authorized:
        return  // NOP

      case .denied, .restricted:
        throw
          SystemFeaturePermissionNotGranted
          .error()
          .pushing(.message("Camera permission denied"))

      case .notDetermined:
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
          AVCaptureDevice.requestAccess(for: .video) { (granted: Bool) in
            if granted {
              continuation.resume()
            }
            else {
              continuation.resume(
                throwing:
                  SystemFeaturePermissionNotGranted
                  .error()
                  .pushing(.message("Camera permission denied"))
              )
            }
          }
        }

      @unknown default:
        throw SystemFeatureStatusUndetermined.error()
      }
    }

    return .init(
      ensurePermission: ensurePermission
    )
  }
}

extension FeatureFactory {

  internal func useOSCamera() {
    self.use(
      OSCamera.live
    )
  }
}
