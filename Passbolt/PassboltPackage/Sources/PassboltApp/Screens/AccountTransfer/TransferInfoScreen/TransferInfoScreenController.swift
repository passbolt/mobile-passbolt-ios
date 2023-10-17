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
import Features
import OSFeatures
import UIComponents

internal struct TransferInfoScreenController {

  internal var presentNoCameraPermissionAlert: @MainActor () -> Void
  internal var requestOrNavigatePublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var presentNoCameraPermissionAlertPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var transferInfoContext: @MainActor () -> Context
  internal var requestAuthorization: @MainActor () async throws -> Void
}

extension TransferInfoScreenController: UIController {

  internal enum Context {
    case export
    case `import`
  }

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> TransferInfoScreenController {
    let features: Features = features

    let navigation: DisplayNavigation = try features.instance()
    let camera: OSCamera = features.instance()
    let presentNoCameraPermissionAlertSubject: PassthroughSubject<Bool, Never> = .init()

    func presentNoCameraPermissionAlert() {
      presentNoCameraPermissionAlertSubject.send(true)
    }

    func requestOrNavigatePublisher() -> AnyPublisher<Bool, Never> {
      Future<Bool, Never> { completion in
        Task {
          do {
            try await camera.ensurePermission()
            completion(.success(true))
          }
          catch {
            completion(.success(false))
          }
        }
      }
      .eraseToAnyPublisher()
    }

    func presentNoCameraPermissionAlertPublisher() -> AnyPublisher<Bool, Never> {
      presentNoCameraPermissionAlertSubject.eraseToAnyPublisher()
    }

    func transferInfoContext() -> Context {
      context
    }

    func requestAuthorization() async throws {
      try await navigation
        .push(
          AccountExportAuthorizationView.self,
          controller: features.instance()
        )
    }

    return Self(
      presentNoCameraPermissionAlert: presentNoCameraPermissionAlert,
      requestOrNavigatePublisher: requestOrNavigatePublisher,
      presentNoCameraPermissionAlertPublisher: presentNoCameraPermissionAlertPublisher,
      transferInfoContext: transferInfoContext,
      requestAuthorization: requestAuthorization
    )
  }
}
