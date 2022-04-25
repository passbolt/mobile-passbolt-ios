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

  private struct FeatureInstance {
    var feature: AnyFeature
    var cancellables: Cancellables
  }

  #if DEBUG  // debug builds allow change and access to environment for mocking and debug
  public var environment: AppEnvironment
  #else  // production builds cannot access environment directly
  private nonisolated let environment: AppEnvironment
  #endif
  private var rootFeatures: Dictionary<ObjectIdentifier, FeatureInstance> = .init()
  private var pendingRootFeatures: Dictionary<ObjectIdentifier, Task<FeatureInstance, Error>> = .init()
  private var scopeFeatures: Dictionary<ObjectIdentifier, FeatureInstance> = .init()
  private var pendingScopeFeatures: Dictionary<ObjectIdentifier, Task<FeatureInstance, Error>> = .init()
  private var scopeID: AnyHashable?

  nonisolated public init(
    environment: AppEnvironment
  ) {
    self.environment = environment
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
    for instance in self.scopeFeatures.values {
      do {
        try await instance.feature.featureUnload()
      }
      catch {
        assertionFailure("Feature unloading failed: \(error)")
      }
    }
    self.scopeFeatures = .init()
  }
}

extension FeatureFactory {

  @FeaturesActor public func instance<F>(
    of feature: F.Type = F.self
  ) async throws -> F
  where F: Feature {
    if let loaded: F = self.rootFeatures[F.featureIdentifier]?.feature as? F {
      return loaded
    }
    else if let loaded: F = self.scopeFeatures[F.featureIdentifier]?.feature as? F {
      return loaded
    }
    else if let pendingLoad: Task<FeatureInstance, Error> = self.pendingRootFeatures[F.featureIdentifier]
      ?? self.pendingScopeFeatures[F.featureIdentifier]
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

      let pendingLoad: Task<FeatureInstance, Error>
      if self.scopeID == nil {
        pendingLoad = Task<FeatureInstance, Error> { @FeaturesActor in
          let loaded: F = try await .load(
            in: self.environment,
            using: self,
            cancellables: featureCancellables
          )
          self.rootFeatures[F.featureIdentifier] = .init(
            feature: loaded,
            cancellables: featureCancellables
          )
          self.pendingRootFeatures[F.featureIdentifier] = .none
          return FeatureInstance(
            feature: loaded,
            cancellables: featureCancellables
          )
        }
        self.pendingRootFeatures[F.featureIdentifier] = pendingLoad
      }
      else {
        pendingLoad = Task<FeatureInstance, Error> { @FeaturesActor in
          let loaded: F = try await .load(
            in: self.environment,
            using: self,
            cancellables: featureCancellables
          )
          assert(self.scopeID != nil)
          self.scopeFeatures[F.featureIdentifier] = .init(
            feature: loaded,
            cancellables: featureCancellables
          )
          self.pendingScopeFeatures[F.featureIdentifier] = .none
          return FeatureInstance(
            feature: loaded,
            cancellables: featureCancellables
          )
        }
        self.pendingScopeFeatures[F.featureIdentifier] = pendingLoad
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
  ) async throws where F: Feature {
    if let pendingFeature: Task<FeatureInstance, Error> = self.pendingScopeFeatures[F.featureIdentifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let feature: F = self.scopeFeatures[F.featureIdentifier]?.feature as? F {
      try await feature.featureUnload()
      self.scopeFeatures[F.featureIdentifier] = nil
    }
    else {
      /* NOP */
    }
    if let pendingFeature: Task<FeatureInstance, Error> = self.pendingRootFeatures[F.featureIdentifier] {
      pendingFeature.cancel()
    }
    else {
      /* NOP */
    }
    if let feature: F = self.rootFeatures[F.featureIdentifier]?.feature as? F {
      try await feature.featureUnload()
      self.rootFeatures[F.featureIdentifier] = nil
    }
    else {
      /* NOP */
    }
  }

  @FeaturesActor public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    #warning("TODO: to check if we should not check for pending instances also")
    if scopeFeatures[F.featureIdentifier]?.feature is F {
      return true
    }
    else if rootFeatures[F.featureIdentifier]?.feature is F {
      return true
    }
    else {
      return false
    }
  }

  @FeaturesActor public func loadIfNeeded<F>(
    _ feature: F.Type = F.self
  ) async throws where F: Feature {
    _ = try await instance(of: F.self)
  }

  @FeaturesActor public func use<F>(
    _ feature: F,
    cancellables: Cancellables = .init()
  ) where F: Feature {
    if self.scopeID == nil {
      assert(
        self.rootFeatures[F.featureIdentifier] == nil
          && self.pendingRootFeatures[F.featureIdentifier] == nil,
        "Feature should not be replaced after initialization"
      )
      self.rootFeatures[F.featureIdentifier] = .init(
        feature: feature,
        cancellables: cancellables
      )
    }
    else {
      assert(
        self.scopeFeatures[F.featureIdentifier] == nil
          && self.pendingScopeFeatures[F.featureIdentifier] == nil,
        "Feature should not be replaced after initialization"
      )
      self.scopeFeatures[F.featureIdentifier] = .init(
        feature: feature,
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
  ) where F: Feature {
    if self.scopeID == nil {
      self.rootFeatures[F.featureIdentifier] = .init(
        feature: F.placeholder,
        cancellables: .init()
      )
    }
    else {
      self.scopeFeatures[F.featureIdentifier] = .init(
        feature: F.placeholder,
        cancellables: .init()
      )
    }
  }

  @FeaturesActor public func patch<F, P>(
    _ keyPath: WritableKeyPath<F, P>,
    with updated: P
  ) where F: Feature {
    if let instance: FeatureInstance = self.rootFeatures[F.featureIdentifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        self.rootFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: instance.cancellables
        )
      }
    }
    else if let instance: FeatureInstance = self.scopeFeatures[F.featureIdentifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        self.scopeFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: instance.cancellables
        )
      }
    }
    else if scopeID == nil {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        self.rootFeatures[F.featureIdentifier] = .init(
          feature: feature,
          cancellables: .init()
        )
      }
    }
    else {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        self.scopeFeatures[F.featureIdentifier] = .init(
          feature: feature,
          cancellables: .init()
        )
      }
    }
  }
}
#endif
