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

internal final class AccountImportInfoViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var alert: AlertViewModel?
  }

  private let camera: OSCamera
  private let navigationToScanning: NavigationToCodeScanning
  private let linkOpener: OSLinkOpener
  private let navigationToSelf: NavigationToAccountImportInfo
  nonisolated let viewState: ViewStateSource<ViewState> = .init(initial: .init())

  internal init(context: Void, features: Features) throws {
    self.camera = features.instance()
    self.navigationToScanning = try features.instance()
    self.linkOpener = features.instance()
    self.navigationToSelf = try features.instance()
  }

  internal func startScanning() async {

    do {
      try await camera.ensurePermission()
      try await navigationToScanning.perform()
    }
    catch {
      self.viewState.update(\.alert, to: .noCameraPermissionsAlert(openSettings))
    }
  }

  internal func back() async {
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }

  private func openSettings() async throws {
    try await linkOpener.openApplicationSettings()
  }
}

extension AlertViewModel {

  fileprivate static func noCameraPermissionsAlert(_ goToSettings: @escaping () async throws -> Void) -> Self {
    .init(
      title: "transfer.account.camera.access.alert.title",
      message: "transfer.account.camera.access.alert.text",
      actions: [
        .cancel(id: .init(), title: .localized(key: .cancel)),
        .regular(
          id: .init(),
          title: .localized(key: .settings),
          perform: { @MainActor in
            await consumingErrors {
              try await goToSettings()
            }
          }
        ),
      ]
    )
  }
}
