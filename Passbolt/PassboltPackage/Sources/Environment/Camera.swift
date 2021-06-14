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

import AVFoundation
import Commons

public struct Camera {
  
  public var checkPermission: () -> AnyPublisher<Camera.PermissionStatus, Never>
  public var requestPermission: () -> AnyPublisher<Bool, Never>
}

extension Camera {
  
  public enum PermissionStatus {
    
    case notDetermined
    case denied
    case authorized
    
    internal static func status(from authorizationStatus: AVAuthorizationStatus) -> Self {
      switch authorizationStatus {
      case .notDetermined:
        return .notDetermined
        
      case .denied, .restricted:
        return .denied
        
      case .authorized:
        return .authorized
        
      @unknown default:
        unreachable("Unexpected state")
      }
    }
  }
}
extension Camera {
  public static func live() -> Self {
    Self(
      checkPermission: {
        let checkPermissionSubject: PassthroughSubject<Camera.PermissionStatus, Never> = .init()
        
        DispatchQueue.main.async {
          defer { checkPermissionSubject.send(completion: .finished) }
          let authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
          checkPermissionSubject.send(.status(from: authorizationStatus))
        }
        
        return checkPermissionSubject.eraseToAnyPublisher()
      },
      requestPermission: {
        let requestPermissionSubject: PassthroughSubject<Bool, Never> = .init()
        
        DispatchQueue.main.async {
          AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
              requestPermissionSubject.send(granted)
              requestPermissionSubject.send(completion: .finished)
            }
          }
        }
        
        return requestPermissionSubject.eraseToAnyPublisher()
      }
    )
  }
}

#if DEBUG
extension Camera {
  
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      checkPermission: Commons.placeholder("You have to provide mocks for used methods"),
      requestPermission: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
