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

import Features

internal struct HomePresentation {

  internal var currentPresentationModePublisher: () -> AnyPublisher<HomePresentationMode, Never>
  internal var setPresentationMode: (HomePresentationMode) -> Void
  internal var availableHomePresentationModes: () -> Array<HomePresentationMode>
}

extension HomePresentation: Feature {

  internal static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let currentPresentationModeSubject: CurrentValueSubject<HomePresentationMode, Never> = .init(.plainResourcesList)

    func currentPresentationModePublisher() -> AnyPublisher<HomePresentationMode, Never> {
      currentPresentationModeSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func setPresentationMode(_ mode: HomePresentationMode) {
      currentPresentationModeSubject.send(mode)
    }

    func availableHomePresentationModes() -> Array<HomePresentationMode> {
      [.plainResourcesList]
    }

    return Self(
      currentPresentationModePublisher: currentPresentationModePublisher,
      setPresentationMode: setPresentationMode(_:),
      availableHomePresentationModes: availableHomePresentationModes
    )
  }
}

#if DEBUG
extension HomePresentation {

  static var placeholder: Self {
    Self(
      currentPresentationModePublisher: unimplemented("You have to provide mocks for used methods"),
      setPresentationMode: unimplemented("You have to provide mocks for used methods"),
      availableHomePresentationModes: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
