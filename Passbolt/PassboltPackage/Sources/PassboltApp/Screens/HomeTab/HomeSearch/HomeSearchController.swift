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
import OSFeatures
import Resources
import Session
import UIComponents

import struct Foundation.Data

internal struct HomeSearchController {

  internal var searchTextPublisher: @MainActor () -> AnyPublisher<String, Never>
  internal var updateSearchText: @MainActor (String) -> Void
  internal var avatarImagePublisher: @MainActor () -> AnyPublisher<Data?, Never>
  internal var presentHomePresentationMenu: @MainActor () -> Void
  internal var homePresentationMenuPresentationPublisher: @MainActor () -> AnyPublisher<HomePresentationMode, Never>
  internal var presentAccountMenu: @MainActor () -> Void
}

extension HomeSearchController: UIController {

  internal typealias Context = (String) -> Void

  @MainActor internal static func instance(
    in context: @escaping Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {

    let asyncExecutor: AsyncExecutor = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()

    let accountDetails: AccountDetails = try features.instance()
    let homePresentation: HomePresentation = try features.instance()

    let searchTextSubject: CurrentValueSubject<String, Never> = .init("")
    let homePresentationMenuPresentationSubject: PassthroughSubject<Void, Never> = .init()

    searchTextSubject
      .sink { text in
        context(text)
      }
      .store(in: cancellables)

    func updateSearchText(_ text: String) {
      searchTextSubject
        .send(text)
    }

    func searchTextPublisher() -> AnyPublisher<String, Never> {
      searchTextSubject
        .eraseToAnyPublisher()
    }

    func avatarImagePublisher() -> AnyPublisher<Data?, Never> {
      Just(Void())
        .asyncMap {
          try? await accountDetails.avatarImage()
        }
        .eraseToAnyPublisher()
    }

    func presentHomePresentationMenu() {
      homePresentationMenuPresentationSubject
        .send()
    }

    func homePresentationMenuPresentationPublisher() -> AnyPublisher<HomePresentationMode, Never> {
      homePresentation
        .currentPresentationModePublisher()
        .map { mode in
          homePresentationMenuPresentationSubject
            .map { mode }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func presentAccountMenu() {
      asyncExecutor.schedule(.reuse) {
        await withLogCatch(
          failInfo: "Navigation to account menu failed!"
        ) {
          try await navigationToAccountMenu.perform()
        }
      }
    }

    return Self(
      searchTextPublisher: searchTextPublisher,
      updateSearchText: updateSearchText,
      avatarImagePublisher: avatarImagePublisher,
      presentHomePresentationMenu: presentHomePresentationMenu,
      homePresentationMenuPresentationPublisher: homePresentationMenuPresentationPublisher,
      presentAccountMenu: presentAccountMenu
    )
  }
}
