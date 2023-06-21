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
import Display
import FeatureScopes
import OSFeatures
import Session

internal final class DefaultPresentationModeSettingsController: ViewController {

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let currentAccount: Account
  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
  private let navigationToSelf: NavigationToDefaultPresentationModeSettings
  private let accountPreferences: AccountPreferences
  private let homePresentation: HomePresentation
  private let useLastUsedHomePresentationAsDefault: StateBinding<Bool>
  private let defaultHomePresentation: StateBinding<HomePresentationMode>

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(SettingsScope.self)
    try features.ensureScope(SessionScope.self)

    self.currentAccount = try features.sessionAccount()
    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()
    self.navigationToSelf = try features.instance()
    self.accountPreferences = try features.instance(context: currentAccount)
    self.homePresentation = try features.instance()

    self.useLastUsedHomePresentationAsDefault =
      accountPreferences
      .useLastHomePresentationAsDefault
    self.defaultHomePresentation = accountPreferences.defaultHomePresentation

    self.viewState = .init(
      initial: .init(
        selectedMode: useLastUsedHomePresentationAsDefault.get(\.self)
          ? .none
          : defaultHomePresentation.get(\.self),
        availableModes: .init()
      )
    )

    self.asyncExecutor.schedule { [unowned self] in
      let availableModes = await self.homePresentation.availableHomePresentationModes()
      await self.viewState.update { state in
        state.availableModes = availableModes
      }
    }
  }
}

extension DefaultPresentationModeSettingsController {

  internal struct ViewState: Hashable {

    internal var selectedMode: HomePresentationMode?
    internal var availableModes: OrderedSet<HomePresentationMode>
  }
}

extension DefaultPresentationModeSettingsController {

  internal final func selectMode(
    _ mode: HomePresentationMode?
  ) {
    self.asyncExecutor.scheduleCatchingWith(
      self.diagnostics,
      behavior: .replace
    ) { [viewState, defaultHomePresentation, useLastUsedHomePresentationAsDefault, navigationToSelf] in
      await viewState.update { viewState in
        viewState.selectedMode = mode
      }
      if let mode: HomePresentationMode = mode {
        useLastUsedHomePresentationAsDefault.set(to: false)
        defaultHomePresentation.set(to: mode)
      }
      else {
        useLastUsedHomePresentationAsDefault.set(to: true)
      }

      try await navigationToSelf.revert()
    }
  }
}
