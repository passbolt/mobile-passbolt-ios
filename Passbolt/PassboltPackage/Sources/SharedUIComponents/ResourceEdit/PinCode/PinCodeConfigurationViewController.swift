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

internal final class PinCodeConfigurationViewController: ViewController {

  internal struct Context {
    internal let onSaveGenerated: @Sendable (String) async -> Void

    internal init(
      onSaveGenerated: @escaping @Sendable (String) async -> Void
    ) {
      self.onSaveGenerated = onSaveGenerated
    }
  }

  internal struct ViewState: Equatable {
    internal var pinCodeLength: Int = 4
  }

  nonisolated let viewState: ViewStateSource<ViewState>

  private let onSaveGenerated: @Sendable (String) async -> Void
  private let pinCodeService: PinCodeService
  private let navigationToSelf: NavigationToPinCodeConfiguration

  internal init(context: Context, features: Features) throws {
    self.onSaveGenerated = context.onSaveGenerated
    self.pinCodeService = try features.instance()
    self.navigationToSelf = try features.instance()
    self.viewState = .init(
      initial: .init()
    )
  }

  internal func saveConfiguration() async {
    await consumingErrors {
      let length: Int = await self.viewState.current.pinCodeLength
      var currentConfiguration: PinCodeService.Configuration = await pinCodeService.currentConfiguration()
      let lengthChanged: Bool = currentConfiguration.pinCodeLength != length
      currentConfiguration.pinCodeLength = length
      await pinCodeService.updateConfiguration(currentConfiguration)
      if lengthChanged {
        let generated: String = await pinCodeService.generate()
        await self.onSaveGenerated(generated)
      }
      try await navigationToSelf.revert()
    }
  }
}
