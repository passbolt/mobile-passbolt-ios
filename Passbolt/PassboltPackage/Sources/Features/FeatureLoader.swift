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

  internal let identifier: FeatureTypeIdentifier
  internal let load: @MainActor (FeatureFactory, Any, Cancellables) async throws -> AnyFeature
  internal let initialize: @MainActor (FeatureFactory, AnyFeature, Any, Cancellables) async throws -> Void
  internal let cacheUnload: (@MainActor (AnyFeature) async throws -> Void)?
}

extension FeatureLoader {

  public static func lazyLoaded<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (FeatureFactory, Feature.Context, Cancellables) async throws -> Feature,
    initialize: @escaping @MainActor (FeatureFactory, Feature, Feature.Context, Cancellables) async throws -> Void =
      { _, _, _, _ in },
    cacheUnload: @escaping @MainActor (Feature) async throws -> Void = { _ in }
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _ factory: FeatureFactory,
      _ context: Any,
      _ cancellables: Cancellables
    ) async throws -> AnyFeature {
      guard let context: Feature.Context = context as? Feature.Context
      else { unreachable("Type safety is guaranteed by framework") }

      return try await load(
        factory,
        context,
        cancellables
      )
    }

    @MainActor func initializeFeature(
      _ factory: FeatureFactory,
      _ feature: AnyFeature,
      _ context: Any,
      _ cancellables: Cancellables
    ) async throws {
      guard let feature: Feature = feature as? Feature
      else { unreachable("Type safety is guaranteed by framework") }

      guard let context: Feature.Context = context as? Feature.Context
      else { unreachable("Type safety is guaranteed by framework") }

      try await initialize(
        factory,
        feature,
        context,
        cancellables
      )
    }

    @MainActor func cacheFeatureUnload(
      _ feature: AnyFeature
    ) async throws {
      guard let feature: Feature = feature as? Feature
      else { unreachable("Type safety is guaranteed by framework") }
      try await cacheUnload(
        feature
      )
    }

    return Self(
      identifier: featureType.typeIdentifier,
      load: loadFeature(_:_:_:),
      initialize: initializeFeature(_:_:_:_:),
      cacheUnload: cacheFeatureUnload(_:)
    )
  }

  public static func lazyLoaded<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (FeatureFactory, Cancellables) async throws -> Feature,
    initialize: @escaping @MainActor (FeatureFactory, Feature, Cancellables) async throws -> Void = { _, _, _ in },
    cacheUnload: @escaping @MainActor (Feature) async throws -> Void = { _ in }
  ) -> Self
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    @MainActor func loadFeature(
      _ factory: FeatureFactory,
      _: Any,
      _ cancellables: Cancellables
    ) async throws -> AnyFeature {
      try await load(
        factory,
        cancellables
      )
    }

    @MainActor func initializeFeature(
      _ factory: FeatureFactory,
      _ feature: AnyFeature,
      _: Any,
      _ cancellables: Cancellables
    ) async throws {
      guard let feature: Feature = feature as? Feature
      else { unreachable("Type safety is guaranteed by framework") }

      try await initialize(
        factory,
        feature,
        cancellables
      )
    }

    @MainActor func cacheFeatureUnload(
      _ feature: AnyFeature
    ) async throws {
      guard let feature: Feature = feature as? Feature
      else { unreachable("Type safety is guaranteed by framework") }
      try await cacheUnload(
        feature
      )
    }

    return Self(
      identifier: featureType.typeIdentifier,
      load: loadFeature(_:_:_:),
      initialize: initializeFeature(_:_:_:_:),
      cacheUnload: cacheFeatureUnload(_:)
    )
  }

  public static func disposable<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (FeatureFactory, Feature.Context) async throws -> Feature
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _ factory: FeatureFactory,
      _ context: Any,
      _: Cancellables
    ) async throws -> AnyFeature {
      guard let context: Feature.Context = context as? Feature.Context
      else { unreachable("Type safety is guaranteed by framework") }
      return try await load(
        factory,
        context
      )
    }

    return Self(
      identifier: featureType.typeIdentifier,
      load: loadFeature(_:_:_:),
      initialize: { _, _, _, _ in },
      cacheUnload: .none
    )
  }

  public static func disposable<Feature>(
    _ featureType: Feature.Type,
    load: @escaping @MainActor (FeatureFactory) async throws -> Feature
  ) -> Self
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    @MainActor func loadFeature(
      _ factory: FeatureFactory,
      _: Any,
      _: Cancellables
    ) async throws -> AnyFeature {
      try await load(factory)
    }

    return Self(
      identifier: featureType.typeIdentifier,
      load: loadFeature(_:_:_:),
      initialize: { _, _, _, _ in },
      cacheUnload: .none
    )
  }

  public static func constant<Feature>(
    _ instance: Feature
  ) -> Self
  where Feature: LoadableFeature {
    @MainActor func loadFeature(
      _: FeatureFactory,
      _: Any,
      _: Cancellables
    ) async throws -> AnyFeature {
      instance
    }

    return Self(
      identifier: Feature.typeIdentifier,
      load: loadFeature(_:_:_:),
      initialize: { _, _, _, _ in },
      cacheUnload: .none
    )
  }
}
