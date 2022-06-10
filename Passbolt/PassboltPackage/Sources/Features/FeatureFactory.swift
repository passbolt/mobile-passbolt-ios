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

import CommonModels

@FeaturesActor
public final class FeatureFactory {

  private struct FeatureCacheItem {
    fileprivate var feature: AnyFeature
    fileprivate var unload: @FeaturesActor () async throws -> Void
    fileprivate var cancellables: Cancellables
  }

  #if DEBUG  // debug builds allow change and access to environment for mocking and debug
  public var environment: AppEnvironment
  #else  // production builds cannot access environment directly
  private nonisolated let environment: AppEnvironment
  #endif
  private var rootFeatureLoaders: Dictionary<FeatureTypeIdentifier, FeatureLoader> = .init()
  private var rootFeaturesCache: Dictionary<FeatureIdentifier, FeatureCacheItem> = .init()
  private var pendingRootFeatures: Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>> = .init()
  private var scopeFeatureLoaders: Dictionary<FeatureTypeIdentifier, FeatureLoader> = .init()
  private var scopeFeaturesCache: Dictionary<FeatureIdentifier, FeatureCacheItem> = .init()
  private var pendingScopeFeatures: Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>> = .init()
  private var scopeID: AnyHashable?

  nonisolated public init(
    environment: AppEnvironment
  ) {
    self.environment = environment
  }

  private var isRoot: Bool {
    self.scopeID == .none
  }

  /// Set scope context mainly for the active user session to automatically
  /// manage lifetime for features associated with user session which
  /// might require reloading its state after changing user.
  ///
  /// If there was no scope set (or set to nil) all features will be
  /// created and cached by root container which won't deallocate its features
  /// unless manually unloaded.
  /// If there was any scope set, all features that were not loaded in root container
  /// will be created and cached by scoped container and will be deallocated
  /// on scope change. Root container features that are already loaded
  /// will have priority over scoped container but
  /// won't be added as long as current scope is not nil.
  ///
  /// If previous scope was not set (or set to nil)
  /// it will create new, scoped container for features.
  /// If previous scope was set and is the same as provided
  /// it will have no efect.
  /// If previous scope was diffrent from provided,
  /// scoped features will be unloaded and fresh scoped container
  /// will be created.
  /// If previous scope was set and provided is nil
  /// scoped features will be unloaded and scope will not be used.
  ///
  /// As long as scope is set to any value besides nil all methods
  /// will be executed within that scope prioritizing caching new and unloading
  /// instances of features from scoped container and loaded from cache
  /// priritizing root container.
  ///
  /// - Parameter scopeID: ID of scope to be set.
  @FeaturesActor public func setScope(
    _ scopeID: AnyHashable?
  ) async {
    #if DEBUG
    guard Self.allowScopes else { return }
    #endif
    guard scopeID != self.scopeID
    else { return }
    self.scopeID = scopeID
    for pending in self.pendingScopeFeatures.values {
      pending.cancel()
    }
    for cacheItem in self.scopeFeaturesCache.values {
      do {
        try await cacheItem.unload()
      }
      catch {
        assertionFailure("Feature unloading failed: \(error)")
      }
    }
    self.scopeFeaturesCache = .init()
  }
}

extension FeatureFactory {

  @FeaturesActor public func use(
    root: Bool = true,
    _ loader: FeatureLoader,
    _ tail: FeatureLoader...
  ) {
    if root {
      self.rootFeatureLoaders[loader.identifier] = loader
      for loader: FeatureLoader in tail {
        self.rootFeatureLoaders[loader.identifier] = loader
      }
    }
    else {
      self.scopeFeatureLoaders[loader.identifier] = loader
      for loader: FeatureLoader in tail {
        self.scopeFeatureLoaders[loader.identifier] = loader
      }
    }
  }

  @FeaturesActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self
  ) async throws -> Feature
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    try await self.instance(
      of: featureType,
      context: ContextlessFeatureContext.instance
    )
  }

  @FeaturesActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self,
    context: Feature.Context
  ) async throws -> Feature
  where Feature: LoadableFeature {
    let featureTypeIdentifier: FeatureTypeIdentifier = Feature.typeIdentifier
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: featureTypeIdentifier,
        featureContextIdentifier: context.identifier
      )

    if let cached: Feature = self.cachedFeature(for: featureIdentifier) {
      return cached
    }
    else if let pending: Task<Feature, Error> = self.pendingFeature(for: featureIdentifier) {
      return try await pending.value
    }
    else if let available = self.loader(for: featureTypeIdentifier) {
      if let cacheUnload: @FeaturesActor (AnyFeature, Cancellables) async throws -> Void = available.loader.cacheUnload
      {
        let cancellables: Cancellables = .init()

        let pendingLoad: Task<FeatureCacheItem, Error>
        if available.isRoot {
          pendingLoad = Task<FeatureCacheItem, Error> { @FeaturesActor in
            guard let loaded: Feature = try await available.loader.load(self, context, cancellables) as? Feature
            else { unreachable("Cannot create wrong type of feature") }

            let unload: @FeaturesActor () async throws -> Void = {
              try await cacheUnload(loaded, cancellables)
            }

            do {
              try await available.loader.initialize(
                self,
                loaded,
                context,
                cancellables
              )
            }
            catch {
              try await unload()
              throw error
            }

            let cacheItem: FeatureCacheItem = .init(
              feature: loaded,
              unload: unload,
              cancellables: cancellables
            )

            self.rootFeaturesCache[featureIdentifier] = cacheItem
            self.pendingRootFeatures[featureIdentifier] = .none

            return cacheItem
          }
          self.pendingRootFeatures[featureIdentifier] = pendingLoad
        }
        else {
          pendingLoad = Task<FeatureCacheItem, Error> { @FeaturesActor in
            guard let loaded: Feature = try await available.loader.load(self, context, cancellables) as? Feature
            else { unreachable("Cannot create wrong type of feature") }

            let unload: @FeaturesActor () async throws -> Void = {
              try await cacheUnload(loaded, cancellables)
            }

            do {
              try await available.loader.initialize(
                self,
                loaded,
                context,
                cancellables
              )
            }
            catch {
              try await unload()
              throw error
            }

            let cacheItem: FeatureCacheItem = .init(
              feature: loaded,
              unload: unload,
              cancellables: cancellables
            )

            self.scopeFeaturesCache[featureIdentifier] = cacheItem
            self.pendingScopeFeatures[featureIdentifier] = .none

            return cacheItem
          }
          self.pendingScopeFeatures[featureIdentifier] = pendingLoad
        }

        guard let loaded: Feature = try await pendingLoad.value.feature as? Feature
        else { unreachable("Cannot create wrong type of feature") }

        return loaded
      }
      else {  // disposable feature, ignoring cache
        guard let loaded: Feature = try await available.loader.load(self, context, Cancellables()) as? Feature
        else { unreachable("Cannot create wrong type of feature") }

        return loaded
      }
    }
    else {
      throw
        FeatureUndefined
        .error(featureName: "\(Feature.self)")
    }
  }

  private func cachedFeature<Feature>(
    _: Feature.Type = Feature.self,
    for featureIdentifier: FeatureIdentifier
  ) -> Feature?
  where Feature: LoadableFeature {
    if let cached: Feature = self.scopeFeaturesCache[featureIdentifier]?.feature as? Feature {
      return cached
    }
    else if let cached: Feature = self.rootFeaturesCache[featureIdentifier]?.feature as? Feature {
      return cached
    }
    else {
      return .none
    }
  }

  private func pendingFeature<Feature>(
    _: Feature.Type = Feature.self,
    for featureIdentifier: FeatureIdentifier
  ) -> Task<Feature, Error>?
  where Feature: LoadableFeature {
    if let pendingLoad: Task<FeatureCacheItem, Error> = self.pendingScopeFeatures[featureIdentifier] {
      return Task {
        guard let loaded: Feature = try await pendingLoad.value.feature as? Feature
        else { unreachable("Cannot create wrong type of feature") }
        return loaded
      }
    }
    else if let pendingLoad: Task<FeatureCacheItem, Error> = self.pendingRootFeatures[featureIdentifier] {
      return Task {
        guard let loaded: Feature = try await pendingLoad.value.feature as? Feature
        else { unreachable("Cannot create wrong type of feature") }
        return loaded
      }
    }
    else {
      return .none
    }
  }

  private func loader(
    for featureTypeIdentifier: FeatureTypeIdentifier
  ) -> (loader: FeatureLoader, isRoot: Bool)? {
    if !self.isRoot, let scopeLoader: FeatureLoader = self.scopeFeatureLoaders[featureTypeIdentifier] {
      return (scopeLoader, isRoot: false)
    }
    else if let rootLoader: FeatureLoader = self.rootFeatureLoaders[featureTypeIdentifier] {
      return (rootLoader, isRoot: true)
    }
    else {
      return .none
    }
  }

  @FeaturesActor public func unload<Feature>(
    _ featureType: Feature.Type,
    context: Feature.Context
  ) async throws
  where Feature: LoadableFeature {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: featureType.typeIdentifier,
        featureContextIdentifier: context.identifier
      )

    if let pendingFeature: Task<FeatureCacheItem, Error> = self.pendingScopeFeatures[featureIdentifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let cacheItem: FeatureCacheItem = self.scopeFeaturesCache[featureIdentifier] {
      try await cacheItem.unload()
      self.scopeFeaturesCache[featureIdentifier] = .none
    }
    else {
      /* NOP */
    }

    if let pendingFeature: Task<FeatureCacheItem, Error> = self.pendingRootFeatures[featureIdentifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let cacheItem: FeatureCacheItem = self.rootFeaturesCache[featureIdentifier] {
      try await cacheItem.unload()
      self.rootFeaturesCache[featureIdentifier] = .none
    }
    else {
      /* NOP */
    }
  }

  @FeaturesActor public func unload<Feature>(
    _ featureType: Feature.Type
  ) async throws
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    try await self.unload(
      featureType,
      context: .instance
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func instance<F>(
    of feature: F.Type = F.self
  ) async throws -> F
  where F: LegacyFeature {
    if let loaded: F = self.rootFeaturesCache[F.identifier]?.feature as? F {
      return loaded
    }
    else if let loaded: F = self.scopeFeaturesCache[F.identifier]?.feature as? F {
      return loaded
    }
    else if let pendingLoad: Task<FeatureCacheItem, Error> = self.pendingRootFeatures[F.identifier]
      ?? self.pendingScopeFeatures[F.identifier]
    {
      if let loaded: F = try await pendingLoad.value.feature as? F {
        return loaded
      }
      else {
        unreachable("Cannot create wrong type of feature")
      }
    }
    else {
      #if DEBUG
      guard Self.autoLoadFeatures
      else {
        // swift-format-ignore: NeverForceUnwrap
        return unimplemented(
          "Failed to load: \(F.self) "
            + "Auto loading of features is disabled,"
            + "please ensure you have provided instances of required features"
        ) as! F  // it looks like compiler issue, casting is required regardless of returning Never here
      }
      #endif
      let featureCancellables: Cancellables = .init()

      let pendingLoad: Task<FeatureCacheItem, Error>
      if self.scopeID == nil {
        pendingLoad = Task<FeatureCacheItem, Error> { @FeaturesActor in
          let loaded: F = try await .load(
            in: self.environment,
            using: self,
            cancellables: featureCancellables
          )
          self.rootFeaturesCache[F.identifier] = .init(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
          self.pendingRootFeatures[F.identifier] = .none
          return FeatureCacheItem(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
        }
        self.pendingRootFeatures[F.identifier] = pendingLoad
      }
      else {
        pendingLoad = Task<FeatureCacheItem, Error> { @FeaturesActor in
          let loaded: F = try await .load(
            in: self.environment,
            using: self,
            cancellables: featureCancellables
          )
          assert(self.scopeID != nil)
          self.scopeFeaturesCache[F.identifier] = .init(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
          self.pendingScopeFeatures[F.identifier] = .none
          return FeatureCacheItem(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
        }
        self.pendingScopeFeatures[F.identifier] = pendingLoad
      }

      if let loaded: F = try await pendingLoad.value.feature as? F {
        return loaded
      }
      else {
        unreachable("Cannot create wrong type of feature")
      }
    }
  }

  @FeaturesActor public func unload<F>(
    _ feature: F.Type
  ) async throws where F: LegacyFeature {
    if let pendingFeature: Task<FeatureCacheItem, Error> = self.pendingScopeFeatures[F.identifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let feature: F = self.scopeFeaturesCache[F.identifier]?.feature as? F {
      try await feature.featureUnload()
      self.scopeFeaturesCache[F.identifier] = nil
    }
    else {
      /* NOP */
    }
    if let pendingFeature: Task<FeatureCacheItem, Error> = self.pendingRootFeatures[F.identifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let feature: F = self.rootFeaturesCache[F.identifier]?.feature as? F {
      try await feature.featureUnload()
      self.rootFeaturesCache[F.identifier] = nil
    }
    else {
      /* NOP */
    }
  }

  @FeaturesActor public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: LegacyFeature {
    #warning("TODO: to check if we should not check for pending instances also")
    if scopeFeaturesCache[F.identifier]?.feature is F {
      return true
    }
    else if rootFeaturesCache[F.identifier]?.feature is F {
      return true
    }
    else {
      return false
    }
  }

  @FeaturesActor public func loadIfNeeded<F>(
    _ feature: F.Type = F.self
  ) async throws where F: LegacyFeature {
    _ = try await instance(of: F.self)
  }

  @FeaturesActor public func use<F>(
    _ feature: F,
    cancellables: Cancellables = .init()
  ) where F: LegacyFeature {
    if self.scopeID == nil {
      assert(
        self.rootFeaturesCache[F.identifier] == nil
          && self.pendingRootFeatures[F.identifier] == nil,
        "Feature should not be replaced after initialization"
      )
      self.rootFeaturesCache[F.identifier] = .init(
        feature: feature,
        unload: feature.featureUnload,
        cancellables: cancellables
      )
    }
    else {
      assert(
        self.scopeFeaturesCache[F.identifier] == nil
          && self.pendingScopeFeatures[F.identifier] == nil,
        "Feature should not be replaced after initialization"
      )
      self.scopeFeaturesCache[F.identifier] = .init(
        feature: feature,
        unload: feature.featureUnload,
        cancellables: cancellables
      )
    }
  }
}

#if DEBUG
// WARNING: debug methods does not take
// into account pending feature loads
extension FeatureFactory {

  public static var autoLoadFeatures: Bool = true
  public static var allowScopes: Bool = true

  @FeaturesActor public func usePlaceholder<F>(
    for featureType: F.Type
  ) where F: LegacyFeature {
    if self.scopeID == nil {
      self.rootFeaturesCache[F.identifier] = .init(
        feature: F.placeholder,
        unload: {},
        cancellables: .init()
      )
    }
    else {
      self.scopeFeaturesCache[F.identifier] = .init(
        feature: F.placeholder,
        unload: {},
        cancellables: .init()
      )
    }
  }

  @FeaturesActor public func patch<F, P>(
    _ keyPath: WritableKeyPath<F, P>,
    with updated: P
  ) where F: LegacyFeature {
    if let instance: FeatureCacheItem = self.rootFeaturesCache[F.identifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        self.rootFeaturesCache[F.identifier] = .init(
          feature: loaded,
          unload: loaded.featureUnload,
          cancellables: instance.cancellables
        )
      }
    }
    else if let instance: FeatureCacheItem = self.scopeFeaturesCache[F.identifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        self.scopeFeaturesCache[F.identifier] = .init(
          feature: loaded,
          unload: loaded.featureUnload,
          cancellables: instance.cancellables
        )
      }
    }
    else if scopeID == nil {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        self.rootFeaturesCache[F.identifier] = .init(
          feature: feature,
          unload: feature.featureUnload,
          cancellables: .init()
        )
      }
    }
    else {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        self.scopeFeaturesCache[F.identifier] = .init(
          feature: feature,
          unload: feature.featureUnload,
          cancellables: .init()
        )
      }
    }
  }
}
#endif
