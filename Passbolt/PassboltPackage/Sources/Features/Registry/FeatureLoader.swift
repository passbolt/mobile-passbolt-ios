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

import Commons

public struct FeatureLoader {

  internal let identifier: FeatureIdentifier
  internal let cache: Bool
  internal let load: @MainActor (Features) throws -> AnyFeature
}

extension FeatureLoader {

  public static func lazyLoaded<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (Features) throws -> Feature
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _ factory: Features
    ) throws -> AnyFeature {
      try load(
        factory
      )
    }

    return Self(
      identifier: featureType.identifier,
      cache: true,
      load: loadFeature(_:)
    )
  }

  public static func disposable<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (Features) throws -> Feature
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _ factory: Features
    ) throws -> AnyFeature {
      try load(factory)
    }

    return Self(
      identifier: featureType.identifier,
      cache: false,
      load: loadFeature(_:)
    )
  }

  @available(*, deprecated)
  public static func constant<Feature>(
    _ instance: Feature
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _: Features
    ) throws -> AnyFeature {
      instance
    }

    return Self(
      identifier: Feature.identifier,
      cache: false,
      load: loadFeature(_:)
    )
  }
}
