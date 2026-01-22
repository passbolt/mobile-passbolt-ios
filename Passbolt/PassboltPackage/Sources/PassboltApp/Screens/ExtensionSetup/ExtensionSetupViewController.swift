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

import Accounts
import Commons
import Display
import OSFeatures
import Session

internal final class ExtensionSetupViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var showSkipButton: Bool = false
  }

  internal struct Context: Sendable {

    internal let allowSkipping: Bool
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let accountInitialSetup: AccountInitialSetup
  private let extensions: OSExtensions
  private let applicationLifecycle: ApplicationLifecycle
  private let linkOpener: OSLinkOpener
  private let navigationToSelf: NavigationToExtensionSetup
  private var shouldAutoDismissOnAppear: Bool = false

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.accountInitialSetup = try features.instance()
    self.extensions = features.instance()
    self.applicationLifecycle = features.instance()
    self.linkOpener = features.instance()
    self.navigationToSelf = try features.instance()

    self.viewState = .init(initial: .init(showSkipButton: context.allowSkipping))
  }

  internal func setupExtension() async {
    do {
      try await self.linkOpener.openSystemSettings()

      let extensionEnabled: Bool = try await withThrowingTaskGroup(of: Bool.self) { group in
        group.addTask { [applicationLifecycle, extensions] in
          for try await _ in applicationLifecycle.lifecycle.asAnyAsyncSequence() {
            let enabled = await extensions.autofillExtensionEnabled()
            if enabled {
              return true
            }
          }
          return false
        }

        return try await group.next() ?? false
      }

      if extensionEnabled {
        self.shouldAutoDismissOnAppear = true
        self.accountInitialSetup.completeSetup(.autofill)
      }
    }
    catch {
      error.logged()
      SnackBarMessageEvent.send(.error(.localized(key: .genericError)))
    }
  }

  internal func skipSetup() async {
    await self.navigationToSelf.revertCatching()
    self.accountInitialSetup.completeSetup(.autofill)
  }

  internal func dismissIfNeeded() {
    guard self.shouldAutoDismissOnAppear else {
      return
    }
    Task {
      try? await self.navigationToSelf.revert()
    }
  }
}
