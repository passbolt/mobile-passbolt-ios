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
public final class FeaturesFactory<Scope>
where Scope: FeaturesScope {

  private let scopeContext: Scope.Context?
  private let registry: FeaturesRegistry
  private let parent: Features?
  private let staticFeatures: Dictionary<FeatureIdentifier, AnyFeature>
  private var loaders: Dictionary<FeatureIdentifier, FeatureLoader>
  private var cache: Dictionary<CacheKey, CacheItem>

	@MainActor public init(
    registrySetup: (inout FeaturesRegistry) -> Void
  ) where Scope == RootFeaturesScope {
    var registry: FeaturesRegistry = .init()
    registrySetup(&registry)
    self.registry = registry
    self.scopeContext = .none
    self.parent = .none
    self.staticFeatures = registry.staticFeatures()
    self.loaders = registry.featureLoaders(for: Scope.self)
    self.cache = .init()
  }

  @MainActor fileprivate init(
    registry: FeaturesRegistry,
    scope: Scope.Type,
    context: Scope.Context,
    parent: Features
  ) {
    self.registry = registry
    self.scopeContext = context
    self.parent = parent
    self.staticFeatures = registry.staticFeatures()
    self.loaders = registry.featureLoaders(for: Scope.self)
    self.cache = .init()
  }
}

extension FeaturesFactory {

  private struct CacheKey: Hashable {

    private let featureTypeIdentifier: FeatureIdentifier
    private let featureContextIdentifier: AnyHashable?

    fileprivate static func key<F>(
      for featureType: F.Type,
      context: AnyHashable? = .none
    ) -> Self
    where F: AnyFeature {
      .init(
        featureTypeIdentifier: featureType.identifier,
        featureContextIdentifier: context
      )
    }
  }

  private struct CacheItem {

    fileprivate var feature: AnyFeature
    fileprivate var cancellables: Cancellables = .init()
  }
}

extension FeaturesFactory: FeaturesContainer {

  public func checkScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) -> Bool
  where RequestedScope: FeaturesScope {
    if Scope.self == RequestedScope.self {
      return true
    }
    else if let parent: Features = self.parent {
      return
        parent
        .checkScope(
          RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      return false
    }
  }

  public func ensureScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws where RequestedScope: FeaturesScope {
    if Scope.self == RequestedScope.self {
      return  // NOP
    }
    else if let parent: Features = self.parent {
      try parent
        .ensureScope(
          RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      throw
        InternalInconsistency
        .error(
          "Required scope is not available",
          file: file,
          line: line
        )
    }
  }

  public func context<RequestedScope>(
    of scope: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws -> RequestedScope.Context
  where RequestedScope: FeaturesScope {
    if Scope.self == RequestedScope.self,
      let context: RequestedScope.Context = self.scopeContext as? RequestedScope.Context
    {
      return context
    }
    else if let parent: Features = self.parent {
      return
        try parent
        .context(
          of: RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid state - requested",
          file: file,
          line: line
        )
    }
  }

  @MainActor public func branch<RequestedScope>(
    scope: RequestedScope.Type,
    context: RequestedScope.Context,
    file: StaticString,
    line: UInt
  ) -> FeaturesContainer
  where RequestedScope: FeaturesScope {
    FeaturesFactory<RequestedScope>(
      registry: self.registry,
      scope: scope,
      context: context,
      parent: self
    )
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) -> Feature
  where Feature: StaticFeature {
    if let feature: Feature = self.staticFeatures[Feature.identifier] as? Feature {
      return feature
    }
    else {
      FeatureUndefined
        .error(
          featureName: "\(Feature.self)",
          file: file,
          line: line
        )
        .asFatalError()
    }
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type,
    context: Feature.Context,
    file: StaticString,
    line: UInt
  ) throws -> Feature
  where Feature: LoadableFeature {
    let cacheKey: CacheKey = .key(
      for: Feature.self,
      context: (context as? LoadableFeatureContext)?.identifier
    )

    if let cached: Feature = self.cache[cacheKey]?.feature as? Feature {
      return cached
    }
    else if let loader: FeatureLoader = self.loaders[Feature.identifier] {
      let cancellables: Cancellables = .init()
      guard let loaded: Feature = try loader.load(FeaturesProxy(container: self), context, cancellables) as? Feature
      else { unreachable("Cannot create wrong type of feature") }

      if loader.cache {
        self.cache[cacheKey] = .init(
          feature: loaded,
          cancellables: cancellables
        )

        return loaded
      }
      else {  // disposable feature, ignoring cache
        return loaded
      }
    }
    else if let parent: Features = self.parent {
      return
        try parent
        .instance(
          of: Feature.self,
          context: context,
          file: file,
          line: line
        )
    }
    else {
      throw
        FeatureUndefined
        .error(
          featureName: "\(Feature.self)",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }
  }
}
