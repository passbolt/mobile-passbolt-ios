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
import OSFeatures
import Session

internal struct DefaultPresentationModeSettingsController {

  internal var viewState: ViewStateBinding<ViewState>
  internal var selectMode: (HomePresentationMode?) -> Void
  internal var navigateBack: () -> Void
}

extension DefaultPresentationModeSettingsController {

  internal struct ViewState: Hashable {

    internal var selectedMode: HomePresentationMode?
    internal var availableModes: OrderedSet<HomePresentationMode>
  }
}

extension DefaultPresentationModeSettingsController: ViewController {

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      selectMode: { _ in unimplemented() },
      navigateBack: { unimplemented() }
    )
  }
  #endif
}

extension DefaultPresentationModeSettingsController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let currentAccount: Account = try features.sessionAccount()

    let executor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let accountPreferences: AccountPreferences = try features.instance(context: currentAccount)
    let homePresentation: HomePresentation = try features.instance()

    let useLastUsedHomePresentationAsDefault: StateBinding<Bool> = accountPreferences
      .useLastHomePresentationAsDefault
    let defaultHomePresentation: StateBinding<HomePresentationMode> = accountPreferences.defaultHomePresentation

    let viewState: ViewStateBinding<ViewState> = .init(
      initial: .init(
        selectedMode: useLastUsedHomePresentationAsDefault.get(\.self)
          ? .none
          : defaultHomePresentation.get(\.self),
        availableModes: .init()
      )
    )

    executor.schedule {
      let availableModes = await homePresentation.availableHomePresentationModes()
      await viewState.mutate { state in
        state.availableModes = availableModes
      }
    }

    nonisolated func selectMode(
      _ mode: HomePresentationMode?
    ) {
      executor.schedule(.replace) {
        await viewState.mutate { viewState in
          viewState.selectedMode = mode
        }
        if let mode: HomePresentationMode = mode {
          useLastUsedHomePresentationAsDefault.set(to: false)
          defaultHomePresentation.set(to: mode)
        }
        else {
          useLastUsedHomePresentationAsDefault.set(to: true)
        }
        await navigation.pop(DefaultPresentationModeSettingsView.self)
      }
    }

    nonisolated func navigateBack() {
      executor.schedule(.reuse) {
        await navigation.pop(DefaultPresentationModeSettingsView.self)
      }
    }

    return Self(
      viewState: viewState,
      selectMode: selectMode(_:),
      navigateBack: navigateBack
    )
  }
}
extension FeaturesRegistry {

  internal mutating func useLiveDefaultPresentationModeSettingsController() {
    self.use(
      .disposable(
        DefaultPresentationModeSettingsController.self,
        load: DefaultPresentationModeSettingsController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
