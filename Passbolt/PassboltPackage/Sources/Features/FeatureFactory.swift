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

@MainActor
public final class FeatureFactory {

  private struct FeatureCacheItem {
    fileprivate var feature: AnyFeature
    fileprivate var unload: @MainActor () async throws -> Void
    fileprivate var cancellables: Cancellables
  }

  #if DEBUG
  public let autoLoadFeatures: Bool
  public let allowScopes: Bool
  #endif
  private var featureLoaders: Dictionary<FeatureTypeIdentifier, FeatureLoader> = .init()
  private var rootFeaturesCache: Dictionary<FeatureIdentifier, FeatureCacheItem> = .init()
  private var rootPendingFeatures: Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>> = .init()

  private var scopeStack: Array<FeaturesScope> = .init()
  private var scopeFeaturesCacheStack: Array<Dictionary<FeatureIdentifier, FeatureCacheItem>> = .init()
  private var scopePendingFeaturesStack: Array<Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>>> = .init()

  private var staticFeatures: Dictionary<FeatureIdentifier, AnyFeature> = .init()

  #if DEBUG
  nonisolated public init(
    autoLoadFeatures: Bool = true,
    allowScopes: Bool = true
  ) {
    self.autoLoadFeatures = autoLoadFeatures
    self.allowScopes = allowScopes
  }
  #else
  nonisolated public init(
  ) {}
  #endif

  @MainActor private var currentScope: FeaturesScope {
    self.scopeStack.last ?? .root
  }

  @MainActor private var isRoot: Bool {
    self.scopeStack.isEmpty
  }

  @MainActor private var currentScopeFeaturesCache: Dictionary<FeatureIdentifier, FeatureCacheItem> {
    get {
      self.scopeFeaturesCacheStack.last
        ?? self.rootFeaturesCache
    }
    set {
      if self.scopeFeaturesCacheStack.isEmpty {
        self.rootFeaturesCache = newValue
      }
      else {
        let lastIndex: Array<Dictionary<FeatureIdentifier, FeatureCacheItem>>.Index =
          self.scopeFeaturesCacheStack
          .index(
            before: self.scopeFeaturesCacheStack
              .endIndex
          )
        self.scopeFeaturesCacheStack[lastIndex] = newValue
      }
    }
  }

  @MainActor private var currentScopePendingFeatures: Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>> {
    get {
      self.scopePendingFeaturesStack.last
        ?? self.rootPendingFeatures
    }
    set {
      if self.scopePendingFeaturesStack.isEmpty {
        self.rootPendingFeatures = newValue
      }
      else {
        let lastIndex: Array<Dictionary<FeatureIdentifier, FeatureCacheItem>>.Index =
          self.scopePendingFeaturesStack
          .index(
            before: self.scopePendingFeaturesStack
              .endIndex
          )
        self.scopePendingFeaturesStack[lastIndex] = newValue
      }
    }
  }

  @MainActor public func assertScope<Identifier>(
    identifier: Identifier
  ) async where Identifier: Hashable {
    #if DEBUG
    guard self.allowScopes else { return }

    let checkedScope: FeaturesScope = .init(
      identifier: identifier
    )

    assert(
      self.scopeStack.contains(checkedScope),
      "Missing required scope: \(identifier)"
    )
    #endif
  }

  @MainActor public func ensureScope<Identifier>(
    identifier: Identifier
  ) async where Identifier: Hashable {
    #if DEBUG
    guard self.allowScopes else { return }
    #endif
    let ensuredScope: FeaturesScope = .init(
      identifier: identifier
    )

    if self.scopeStack.contains(ensuredScope) {
      return  // NOP
    }
    else if ensuredScope == .root {
      await self.clearScope()
    }
    else {
      self.scopeStack = .init(
        repeating: ensuredScope,
        count: 1
      )
      for pendingFeatures in self.scopePendingFeaturesStack {
        for pending in pendingFeatures.values {
          pending.cancel()
        }
      }
      self.scopePendingFeaturesStack = .init(
        repeating: .init(),
        count: 1
      )

      for featuresCache in self.scopeFeaturesCacheStack {
        for cacheItem in featuresCache.values {
          do {
            try await cacheItem.unload()
          }
          catch {
            assertionFailure("Feature unloading failed: \(error)")
          }
        }
      }
      self.scopeFeaturesCacheStack = .init(
        repeating: .init(),
        count: 1
      )
    }
  }

  @MainActor public func pushScope<Identifier>(
    identifier: Identifier
  ) -> () async -> Void
  where Identifier: Hashable {
    self.pushScope(
      .init(
        identifier: identifier
      )
    )
  }

  @MainActor public func pushScope(
    _ scope: FeaturesScope
  ) -> () async -> Void {
    #if DEBUG
    guard self.allowScopes else { return {} }
    #endif
    self.scopeStack.append(scope)
    self.scopePendingFeaturesStack.append(.init())
    self.scopeFeaturesCacheStack.append(.init())
    return self.popScope
  }

  @MainActor private func popScope() async {
    #if DEBUG
    guard self.allowScopes else { return }
    #endif
    _ = self.scopeStack.popLast()
    if let pendingFeatures = self.scopePendingFeaturesStack.popLast() {
      for pending in pendingFeatures.values {
        pending.cancel()
      }
    }
    else { /* NOP */
    }
    if let featuresCache = self.scopeFeaturesCacheStack.popLast() {
      for cacheItem in featuresCache.values {
        do {
          try await cacheItem.unload()
        }
        catch {
          assertionFailure("Feature unloading failed: \(error)")
        }
      }
    }
    else { /* NOP */
    }
  }

  @MainActor public func clearScope() async {
    self.scopeStack = .init()
    for pendingFeatures in self.scopePendingFeaturesStack {
      for pending in pendingFeatures.values {
        pending.cancel()
      }
    }
    self.scopePendingFeaturesStack = .init()

    for featuresCache in self.scopeFeaturesCacheStack {
      for cacheItem in featuresCache.values {
        do {
          try await cacheItem.unload()
        }
        catch {
          assertionFailure("Feature unloading failed: \(error)")
        }
      }
    }
    self.scopeFeaturesCacheStack = .init()
  }
}

extension FeatureFactory {

  @MainActor public func use(
    _ loader: FeatureLoader,
    _ tail: FeatureLoader...
  ) {
    self.featureLoaders[loader.identifier] = loader
    for loader: FeatureLoader in tail {
      self.featureLoaders[loader.identifier] = loader
    }
  }

  @MainActor public func use<Feature>(
    _ staticFeature: Feature
  ) where Feature: StaticFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: Feature.typeIdentifier,
      featureContextIdentifier: ContextlessFeatureContext.instance.identifier
    )
    assert(self.staticFeatures[identifier] == nil)
    self.staticFeatures[identifier] = staticFeature
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self
  ) async throws -> Feature
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    try await self.instance(
      of: featureType,
      context: ContextlessFeatureContext.instance
    )
  }

  @MainActor public func instance<Feature>(
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

    if let cached: Feature = self.cacheItem(for: featureIdentifier)?.feature as? Feature {
      return cached
    }
    else if let pending: Feature = try await self.pendingFeature(for: featureIdentifier) as? Feature {
      return pending
    }
    else if let loader: FeatureLoader = self.loader(for: featureTypeIdentifier) {
      if let cacheUnload: @MainActor (AnyFeature) async throws -> Void = loader.cacheUnload {
        let cancellables: Cancellables = .init()

        let pendingLoad: Task<FeatureCacheItem, Error>
        if self.isRoot {
          pendingLoad = Task<FeatureCacheItem, Error> { @MainActor in
            guard let loaded: Feature = try await loader.load(self, context, cancellables) as? Feature
            else { unreachable("Cannot create wrong type of feature") }

            let unload: @MainActor () async throws -> Void = {
              try await cacheUnload(loaded)
            }

            do {
              try Task.checkCancellation()
            }
            catch {
              try await unload()
              throw error
            }

            do {
              try await loader.initialize(
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

            do {
              try Task.checkCancellation()
            }
            catch {
              try await unload()
              throw error
            }

            self.rootFeaturesCache[featureIdentifier] = cacheItem
            self.rootPendingFeatures[featureIdentifier] = .none

            return cacheItem
          }
          self.rootPendingFeatures[featureIdentifier] = pendingLoad
        }
        else {
          let scopeIndex: Int = self.scopeStack.index(before: self.scopeStack.endIndex)
          pendingLoad = Task<FeatureCacheItem, Error> { @MainActor in
            guard let loaded: Feature = try await loader.load(self, context, cancellables) as? Feature
            else { unreachable("Cannot create wrong type of feature") }

            let unload: @MainActor () async throws -> Void = {
              try await cacheUnload(loaded)
            }

            do {
              try Task.checkCancellation()
            }
            catch {
              try await unload()
              throw error
            }

            do {
              try await loader.initialize(
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

            do {
              try Task.checkCancellation()
            }
            catch {
              try await unload()
              throw error
            }

            self.scopeFeaturesCacheStack[scopeIndex][featureIdentifier] = cacheItem
            self.scopePendingFeaturesStack[scopeIndex][featureIdentifier] = .none

            return cacheItem
          }
          self.scopePendingFeaturesStack[scopeIndex][featureIdentifier] = pendingLoad
        }

        guard let loaded: Feature = try await pendingLoad.value.feature as? Feature
        else { unreachable("Cannot create wrong type of feature") }

        return loaded
      }
      else {  // disposable feature, ignoring cache
        guard let loaded: Feature = try await loader.load(self, context, Cancellables()) as? Feature
        else { unreachable("Cannot create wrong type of feature") }

        return loaded
      }
    }
    else {
      throw
        FeatureUndefined
        .error(featureName: "\(Feature.self)")
        .asAssertionFailure()
    }
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self
  ) -> Feature
  where Feature: StaticFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: Feature.typeIdentifier,
      featureContextIdentifier: ContextlessFeatureContext.instance.identifier
    )
    if let feature: Feature = self.staticFeatures[identifier] as? Feature {
      return feature
    }
    else {
      FeatureUndefined
        .error(featureName: "\(Feature.self)")
        .asFatalError()
    }
  }

  private func cacheItem(
    for featureIdentifier: FeatureIdentifier
  ) -> FeatureCacheItem? {
    if let featuresCache: Dictionary<FeatureIdentifier, FeatureCacheItem> = self.scopeFeaturesCacheStack
      .first(
        where: { cache in
          cache.keys.contains(featureIdentifier)
        }
      ),
      let cacheItem: FeatureCacheItem = featuresCache[featureIdentifier]
    {
      return cacheItem
    }
    else if let cacheItem: FeatureCacheItem = self.rootFeaturesCache[featureIdentifier] {
      return cacheItem
    }
    else {
      return .none
    }
  }

  private func pendingFeature(
    for featureIdentifier: FeatureIdentifier
  ) async throws -> AnyFeature? {
    if let pendingFeatures: Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>> = self
      .scopePendingFeaturesStack
      .first(
        where: { cache in
          cache.keys.contains(featureIdentifier)
        }
      ),
      let pendingLoad: Task<FeatureCacheItem, Error> = pendingFeatures[featureIdentifier]
    {
      return try await pendingLoad.value.feature
    }
    else if let pendingLoad: Task<FeatureCacheItem, Error> = self.rootPendingFeatures[featureIdentifier] {
      return try await pendingLoad.value.feature
    }
    else {
      return .none
    }
  }

  private func loader(
    for featureTypeIdentifier: FeatureTypeIdentifier
  ) -> FeatureLoader? {
    self.featureLoaders[featureTypeIdentifier]
  }

  @MainActor public func unload<Feature>(
    _ featureType: Feature.Type,
    context: Feature.Context
  ) async throws
  where Feature: LoadableFeature {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: featureType.typeIdentifier,
        featureContextIdentifier: context.identifier
      )
    try await self.unload(
      featureIdentifier
    )
  }

  @MainActor public func unload<Feature>(
    _ featureType: Feature.Type
  ) async throws
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: featureType.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    try await self.unload(
      featureIdentifier
    )
  }

  @MainActor private func unload(
    _ featureIdentifier: FeatureIdentifier
  ) async throws {
    if let pendingFeaturesIndex: Array<Dictionary<FeatureIdentifier, Task<FeatureCacheItem, Error>>>.Index = self
      .scopePendingFeaturesStack
      .firstIndex(
        where: { cache in
          cache.keys.contains(featureIdentifier)
        }
      ),
      let pendingLoad: Task<FeatureCacheItem, Error> = self.scopePendingFeaturesStack[pendingFeaturesIndex][
        featureIdentifier
      ]
    {
      pendingLoad.cancel()
      self.scopePendingFeaturesStack[pendingFeaturesIndex][featureIdentifier] = .none
    }
    else {
      /* NOP */
    }
    if let cacheItem: FeatureCacheItem = self.currentScopeFeaturesCache[featureIdentifier] {
      try await cacheItem.unload()
      self.currentScopeFeaturesCache[featureIdentifier] = .none
    }
    else {
      /* NOP */
    }

    if let pendingFeature: Task<FeatureCacheItem, Error> = self.rootPendingFeatures[featureIdentifier] {
      pendingFeature.cancel()
      self.rootPendingFeatures[featureIdentifier] = .none
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
}

extension FeatureFactory {

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func instance<Feature>(
    of feature: Feature.Type = Feature.self
  ) async throws -> Feature
  where Feature: LegacyFeature {
    let featureTypeIdentifier: FeatureTypeIdentifier = Feature.typeIdentifier
    let featureIdentifier: FeatureIdentifier = Feature.identifier

    if let cached: Feature = self.cacheItem(for: featureIdentifier)?.feature as? Feature {
      return cached
    }
    else if let pending: Feature = try await self.pendingFeature(for: featureIdentifier) as? Feature {
      return pending
    }
    else {
      #if DEBUG
      guard self.autoLoadFeatures
      else {
        throw
          FeatureUndefined
          .error(featureName: "\(Feature.self)")
          .asAssertionFailure()
      }
      #endif
      let featureCancellables: Cancellables = .init()

      let pendingLoad: Task<FeatureCacheItem, Error>
      if self.isRoot {
        pendingLoad = Task<FeatureCacheItem, Error> { @MainActor in
          let loaded: Feature = try await .load(
            using: self,
            cancellables: featureCancellables
          )

          do {
            try Task.checkCancellation()
          }
          catch {
            try await loaded.featureUnload()
            throw error
          }

          self.rootFeaturesCache[featureIdentifier] = .init(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
          self.rootPendingFeatures[featureIdentifier] = .none

          return FeatureCacheItem(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
        }
        self.rootPendingFeatures[featureIdentifier] = pendingLoad
      }
      else {
        let scopeIndex: Int = self.scopeStack.index(before: self.scopeStack.endIndex)
        pendingLoad = Task<FeatureCacheItem, Error> { @MainActor in
          let loaded: Feature = try await .load(
            using: self,
            cancellables: featureCancellables
          )

          let cacheItem: FeatureCacheItem = .init(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )

          do {
            try Task.checkCancellation()
          }
          catch {
            try await loaded.featureUnload()
            throw error
          }

          self.scopeFeaturesCacheStack[scopeIndex][featureIdentifier] = .init(
            feature: loaded,
            unload: loaded.featureUnload,
            cancellables: featureCancellables
          )
          self.scopePendingFeaturesStack[scopeIndex][featureIdentifier] = .none

          return cacheItem
        }
        self.scopePendingFeaturesStack[scopeIndex][featureIdentifier] = pendingLoad
      }

      if let loaded: Feature = try await pendingLoad.value.feature as? Feature {
        return loaded
      }
      else {
        unreachable("Cannot create wrong type of feature")
      }
    }
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func unload<F>(
    _ feature: F.Type
  ) async throws where F: LegacyFeature {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: feature.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    try await self.unload(
      featureIdentifier
    )
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: LegacyFeature {
    #warning("TODO: to check if we should not check for pending instances also")
    return self.cacheItem(
      for: .init(
        featureTypeIdentifier: feature.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    ) != nil
  }

  @available(*, deprecated, message: "Please avoid checking feature loading state.")
  @MainActor public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: LoadableFeature, F.Context == ContextlessFeatureContext {
    #warning("TODO: to check if we should not check for pending instances also")
    return self.cacheItem(
      for: .init(
        featureTypeIdentifier: feature.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    ) != nil
  }

  @available(*, deprecated, message: "Please avoid checking feature loading state.")
  @MainActor public func isLoaded<F>(
    _ feature: F.Type,
    context: F.Context
  ) -> Bool where F: LoadableFeature {
    #warning("TODO: to check if we should not check for pending instances also")
    return self.cacheItem(
      for: .init(
        featureTypeIdentifier: feature.typeIdentifier,
        featureContextIdentifier: context.identifier
      )
    ) != nil
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func loadIfNeeded<F>(
    _ feature: F.Type = F.self
  ) async throws where F: LegacyFeature {
    _ = try await instance(of: F.self)
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func use<F>(
    _ feature: F,
    cancellables: Cancellables = .init()
  ) where F: LegacyFeature {
    assert(
      self.currentScopeFeaturesCache[F.identifier] == nil
        && self.currentScopePendingFeatures[F.identifier] == nil,
      "Feature should not be replaced after initialization"
    )
    self.currentScopeFeaturesCache[F.identifier] = .init(
      feature: feature,
      unload: feature.featureUnload,
      cancellables: cancellables
    )
  }
}

#if DEBUG
// WARNING: debug methods does not take
// into account pending feature loads
extension FeatureFactory {

  @MainActor public func isCached<Feature>(
    _ featureType: Feature.Type,
    context: Feature.Context
  ) -> Bool
  where Feature: LoadableFeature {
    #warning("TODO: to check if we should not check for pending instances also")
    return self.cacheItem(
      for: .init(
        featureTypeIdentifier: featureType.typeIdentifier,
        featureContextIdentifier: context.identifier
      )
    ) != nil
  }

  @MainActor public func isCached<Feature>(
    _ featureType: Feature.Type
  ) -> Bool
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.isCached(
      featureType,
      context: .instance
    )
  }

  @MainActor public func usePlaceholder<Feature>(
    for featureType: Feature.Type,
    context: Feature.Context
  ) where Feature: LoadableFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: featureType.typeIdentifier,
      featureContextIdentifier: context.identifier
    )
    self.currentScopeFeaturesCache[identifier] = .init(
      feature: Feature.placeholder,
      unload: {},
      cancellables: .init()
    )
  }

  @MainActor public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.usePlaceholder(
      for: featureType,
      context: .instance
    )
  }

  @MainActor public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: Feature.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    self.staticFeatures[featureIdentifier] = Feature.placeholder
  }

  @MainActor public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    context: Feature.Context,
    with updated: Property
  ) where Feature: LoadableFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: Feature.typeIdentifier,
      featureContextIdentifier: context.identifier
    )

    if let cacheItem: FeatureCacheItem = self.cacheItem(for: identifier),
      var loaded: Feature = cacheItem.feature as? Feature
    {
      withExtendedLifetime(loaded[keyPath: keyPath]) {
        loaded[keyPath: keyPath] = updated
        self.currentScopeFeaturesCache[identifier] = .init(
          feature: loaded,
          unload: cacheItem.unload,
          cancellables: cacheItem.cancellables
        )
      }
    }
    else {
      var feature: Feature = .placeholder
      feature[keyPath: keyPath] = updated
      self.currentScopeFeaturesCache[identifier] = .init(
        feature: feature,
        unload: { /* NOP */  },
        cancellables: .init()
      )
    }
  }

  @MainActor public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.patch(
      keyPath,
      context: .instance,
      with: updated
    )
  }

  @MainActor public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: StaticFeature {
    let featureIdentifier: FeatureIdentifier =
      .init(
        featureTypeIdentifier: Feature.typeIdentifier,
        featureContextIdentifier: ContextlessFeatureContext.instance.identifier
      )
    if var feature: Feature = self.staticFeatures[featureIdentifier] as? Feature {
      feature[keyPath: keyPath] = updated
      self.staticFeatures[featureIdentifier] = feature
    }
    else {
      var feature: Feature = .placeholder
      feature[keyPath: keyPath] = updated
      self.staticFeatures[featureIdentifier] = feature
    }
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func usePlaceholder<F>(
    for featureType: F.Type
  ) where F: LegacyFeature {
    self.currentScopeFeaturesCache[F.identifier] = .init(
      feature: F.placeholder,
      unload: {},
      cancellables: .init()
    )
  }

  @available(*, deprecated, message: "Please switch to `LoadableFeature`")
  @MainActor public func patch<F, P>(
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
    else if let instance: FeatureCacheItem = self.currentScopeFeaturesCache[F.identifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        self.currentScopeFeaturesCache[F.identifier] = .init(
          feature: loaded,
          unload: loaded.featureUnload,
          cancellables: instance.cancellables
        )
      }
    }
    else {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        self.currentScopeFeaturesCache[F.identifier] = .init(
          feature: feature,
          unload: feature.featureUnload,
          cancellables: .init()
        )
      }
    }
  }

  @MainActor internal func set(
    staticFeatures: Dictionary<FeatureIdentifier, AnyFeature>
  ) {
    self.staticFeatures = staticFeatures
  }

  @MainActor internal func set(
    dynamicFeatures: Dictionary<FeatureIdentifier, AnyFeature>
  ) {
    self.rootFeaturesCache = dynamicFeatures.mapValues({ (feature: AnyFeature) in
      FeatureCacheItem(
        feature: feature,
        unload: {},
        cancellables: .init()
      )
    })
  }
}
#endif
