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

internal final class DefaultPresentationModeSettingsViewController: ViewController {

  internal struct ViewState: Hashable {

    internal var selectedMode: HomePresentationMode?
    internal var availableModes: OrderedSet<HomePresentationMode>
  }

  internal nonisolated let viewState: ComputedViewState<ViewState>

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

    let currentAccount: Account = try features.sessionAccount()

    self.navigationToSelf = try features.instance()
    self.accountPreferences = try features.instance(context: currentAccount)
    self.homePresentation = try features.instance()

    let useLastUsedHomePresentationAsDefault: StateBinding<Bool> = accountPreferences
      .useLastHomePresentationAsDefault
    self.useLastUsedHomePresentationAsDefault = useLastUsedHomePresentationAsDefault
    let defaultHomePresentation: StateBinding<HomePresentationMode> = accountPreferences.defaultHomePresentation
    self.defaultHomePresentation = defaultHomePresentation

    self.viewState = .init(
      initial: .init(
        selectedMode: .none,
        availableModes: .init()
      ),
      updateUsing: self.accountPreferences.updates,
      update: {
        [homePresentation, useLastUsedHomePresentationAsDefault, defaultHomePresentation] (state: inout ViewState) in
        state.selectedMode =
          useLastUsedHomePresentationAsDefault.get(\.self)
          ? .none
          : defaultHomePresentation.get(\.self)

        state.availableModes = homePresentation.availableHomePresentationModes()
      }
    )
  }
}

extension DefaultPresentationModeSettingsViewController {

  internal final func selectMode(
    _ mode: HomePresentationMode?
  ) async {
    if let mode: HomePresentationMode = mode {
      useLastUsedHomePresentationAsDefault.set(to: false)
      defaultHomePresentation.set(to: mode)
    }
    else {
      useLastUsedHomePresentationAsDefault.set(to: true)
    }

    await navigationToSelf.revertCatching()
  }
}
