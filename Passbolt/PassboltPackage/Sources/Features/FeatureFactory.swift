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

import class Foundation.NSRecursiveLock

public final class FeatureFactory {

  private struct FeatureInstance {
    var feature: AnyFeature
    var cancellables: Cancellables
  }

  #if DEBUG  // debug builds allow change and access to environment for mocking and debug
  public var environment: AppEnvironment
  #else  // production builds cannot access environment directly
  private let environment: AppEnvironment
  #endif
  private let featuresAccessLock: NSRecursiveLock = .init()
  private var rootFeatures: Dictionary<ObjectIdentifier, FeatureInstance> = .init()
  private var scopeFeatures: Dictionary<ObjectIdentifier, FeatureInstance> = .init()
  private var scopeID: AnyHashable? {
    didSet {
      guard scopeID != oldValue
      else { return }
      for instance in scopeFeatures.values {
        assert(
          instance.feature.featureUnload(),
          "Feature unloading failed"
        )
      }
      scopeFeatures = .init()
    }
  }

  public init(
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
  public func setScope(
    _ scopeID: AnyHashable?
  ) {
    #if DEBUG
    guard Self.allowScopes else { return }
    #endif
    self.featuresAccessLock.lock()
    self.scopeID = scopeID
    self.featuresAccessLock.unlock()
  }
}

extension FeatureFactory {

  public func instance<F>(
    of feature: F.Type = F.self
  ) -> F
  where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    if let loaded: F = rootFeatures[F.featureIdentifier]?.feature as? F {
      return loaded
    }
    else if let loaded: F = scopeFeatures[F.featureIdentifier]?.feature as? F {
      return loaded
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

      let loaded: F = .load(
        in: environment,
        using: self,
        cancellables: featureCancellables
      )
      if scopeID == nil {
        rootFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: featureCancellables
        )
      }
      else {
        scopeFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: featureCancellables
        )
      }
      return loaded
    }
  }

  @discardableResult
  public func unload<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    if (scopeFeatures[F.featureIdentifier]?.feature as? F)?.featureUnload() ?? false {
      scopeFeatures[F.featureIdentifier] = nil
      return true
    }
    else if (rootFeatures[F.featureIdentifier]?.feature as? F)?.featureUnload() ?? false {
      rootFeatures[F.featureIdentifier] = nil
      return true
    }
    else {
      return false
    }
  }

  public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
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

  public func loadIfNeeded<F>(
    _ feature: F.Type = F.self
  ) where F: Feature {
    _ = instance(of: F.self)
  }

  public func use<F>(
    _ feature: F,
    cancellables: Cancellables = .init()
  ) where F: Feature {
    featuresAccessLock.lock()
    if scopeID == nil {
      assert(
        rootFeatures[F.featureIdentifier] == nil,
        "Feature should not be replaced after initialization"
      )
      rootFeatures[F.featureIdentifier] = .init(
        feature: feature,
        cancellables: cancellables
      )
    }
    else {
      assert(
        scopeFeatures[F.featureIdentifier] == nil,
        "Feature should not be replaced after initialization"
      )
      scopeFeatures[F.featureIdentifier] = .init(
        feature: feature,
        cancellables: cancellables
      )
    }
    featuresAccessLock.unlock()
  }
}

#if DEBUG
extension FeatureFactory {

  public static var autoLoadFeatures: Bool = true
  public static var allowScopes: Bool = true

  public func usePlaceholder<F>(
    for featureType: F.Type
  ) where F: Feature {
    featuresAccessLock.lock()
    if scopeID == nil {
      rootFeatures[F.featureIdentifier] = .init(
        feature: F.placeholder,
        cancellables: .init()
      )
    }
    else {
      scopeFeatures[F.featureIdentifier] = .init(
        feature: F.placeholder,
        cancellables: .init()
      )
    }
    featuresAccessLock.unlock()

  }

  public func patch<F, P>(
    _ keyPath: WritableKeyPath<F, P>,
    with updated: P
  ) where F: Feature {
    featuresAccessLock.lock()
    if let instance: FeatureInstance = rootFeatures[F.featureIdentifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        rootFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: instance.cancellables
        )
      }
    }
    else if let instance: FeatureInstance = scopeFeatures[F.featureIdentifier],
      var loaded: F = instance.feature as? F
    {
      withExtendedLifetime(loaded) {
        loaded[keyPath: keyPath] = updated
        scopeFeatures[F.featureIdentifier] = .init(
          feature: loaded,
          cancellables: instance.cancellables
        )
      }
    }
    else if scopeID == nil {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        rootFeatures[F.featureIdentifier] = .init(
          feature: feature,
          cancellables: .init()
        )
      }
    }
    else {
      var feature: F = .placeholder
      withExtendedLifetime(feature) {
        feature[keyPath: keyPath] = updated
        scopeFeatures[F.featureIdentifier] = .init(
          feature: feature,
          cancellables: .init()
        )
      }
    }
    featuresAccessLock.unlock()
  }
}
#endif
