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
    var feature: Any
    var cancellables: Cancellables
  }

  #if DEBUG  // debug builds allow change and access to environment for mocking and debug
  public var environment: Environment
  #else  // production builds cannot access environment directly
  private let environment: Environment
  #endif
  private let featuresAccessLock: NSRecursiveLock = .init()
  private var features: Dictionary<ObjectIdentifier, FeatureInstance> = .init()

  public init(
    environment: Environment
  ) {
    self.environment = environment
  }
}

extension FeatureFactory {

  public func instance<F>(
    of feature: F.Type = F.self
  ) -> F
  where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    if let loaded: F = features[F.featureIdentifier]?.feature as? F {
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
      features[F.featureIdentifier] = .init(
        feature: loaded,
        cancellables: featureCancellables
      )
      return loaded
    }
  }

  @discardableResult
  public func unload<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    guard (features[F.featureIdentifier]?.feature as? F)?.featureUnload() ?? false else { return false }
    features[F.featureIdentifier] = nil
    return true
  }

  public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    return features[F.featureIdentifier]?.feature is F
  }

  public func use<F>(
    _ feature: F,
    cancellables: Cancellables = .init()
  ) where F: Feature {
    featuresAccessLock.lock()
    assert(
      features[F.featureIdentifier] == nil,
      "Feature should not be replaced after initialization"
    )
    features[F.featureIdentifier] = .init(
      feature: feature,
      cancellables: cancellables
    )
    featuresAccessLock.unlock()
  }
}

#if DEBUG
extension FeatureFactory {

  public static var autoLoadFeatures: Bool = true

  public func usePlaceholder<F>(
    for featureType: F.Type
  ) where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    features[F.featureIdentifier] = .init(feature: F.placeholder, cancellables: .init())
  }

  public func patch<F, P>(
    _ keyPath: WritableKeyPath<F, P>,
    with updated: P
  ) where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    if let instance: FeatureInstance = features[F.featureIdentifier],
      var loaded: F = instance.feature as? F
    {
      loaded[keyPath: keyPath] = updated
      features[F.featureIdentifier] = .init(
        feature: loaded,
        cancellables: instance.cancellables
      )
    }
    else {
      var feature: F = .placeholder
      feature[keyPath: keyPath] = updated
      features[F.featureIdentifier] = .init(
        feature: feature,
        cancellables: .init()
      )
    }

  }
}
#endif
