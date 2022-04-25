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
import Features

internal struct HomePresentation {

  internal var currentPresentationModePublisher: @MainActor () -> AnyPublisher<HomePresentationMode, Never>
  internal var setPresentationMode: @MainActor (HomePresentationMode) -> Void
  internal var availableHomePresentationModes: @MainActor () -> Array<HomePresentationMode>
}

extension HomePresentation: Feature {

  internal static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let featureConfig: FeatureConfig = try await features.instance()

    let foldersConfig: FeatureFlags.Folders = await featureConfig.configuration(for: FeatureFlags.Folders.self)
    let tagsConfig: FeatureFlags.Tags = await featureConfig.configuration(for: FeatureFlags.Tags.self)

    let currentPresentationModeSubject: CurrentValueSubject<HomePresentationMode, Never> = .init(.plainResourcesList)

    @MainActor func currentPresentationModePublisher() -> AnyPublisher<HomePresentationMode, Never> {
      currentPresentationModeSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    @MainActor func setPresentationMode(_ mode: HomePresentationMode) {
      currentPresentationModeSubject.send(mode)
    }

    @MainActor func availableHomePresentationModes() -> Array<HomePresentationMode> {
      // order is preserved on display
      var availableModes: Array<HomePresentationMode> = [
        .plainResourcesList,
        .favoriteResourcesList,
        .modifiedResourcesList,
        .sharedResourcesList,
        .ownedResourcesList,
      ]

      switch foldersConfig {
      case .disabled:
        break  // skip

      case .enabled:
        if #available(iOS 15, *) {
          availableModes.append(.foldersExplorer)
        }
        else {
          break  // temporarily disable on iOS 14
        }
      }

      switch tagsConfig {
      case .disabled:
        break  // skip

      case .enabled:
        if #available(iOS 15, *) {
          availableModes.append(.tagsExplorer)
        }
        else {
          break  // temporarily disable on iOS 14
        }
      }

      if #available(iOS 15, *) {
        availableModes.append(.resourceUserGroupsExplorer)
      }
      else {
        // NOP - temporarily disable on iOS 14
      }

      return availableModes
    }

    return Self(
      currentPresentationModePublisher: currentPresentationModePublisher,
      setPresentationMode: setPresentationMode(_:),
      availableHomePresentationModes: availableHomePresentationModes
    )
  }
}

extension HomePresentation {

  internal var featureUnload: @FeaturesActor () async throws -> Void { {} }
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
