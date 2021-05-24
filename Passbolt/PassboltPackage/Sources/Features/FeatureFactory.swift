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
import class Foundation.NSRecursiveLock

public final class FeatureFactory {
  
  private typealias FeatureInstance = (feature: Any, cancellables: Array<AnyCancellable>)
  
  #if DEBUG // debug builds allow change and access to environment for mocking and debug
  public var environment: RootEnvironment
  #else // production builds cannot access environment directly
  private let environment: RootEnvironment
  #endif
  private let featuresAccessLock: NSRecursiveLock = .init()
  private var features: Dictionary<ObjectIdentifier, FeatureInstance> = .init()
  
  public init(
    environment: RootEnvironment
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
    } else {
      #if DEBUG
      guard Self.autoLoadFeatures
      else { return placeholder(
        "Auto loading of features is disabled,"
        + "please ensure you have provided instances of required features"
        // swiftlint:disable:next force_cast
        ) as! F // it looks like compiler issue, casting is required regardless of returning Never here
      }
      #endif
      var featureCancellables: Array<AnyCancellable> = .init()
      
      let loaded: F = .load(
        in: F.environmentScope(environment),
        using: self,
        cancellables: &featureCancellables
      )
      features[F.featureIdentifier] = FeatureInstance(
        feature: loaded,
        cancellables: featureCancellables
      )
      return loaded
    }
  }
  
  public func unload<F>(
    _ feature: F.Type
  ) where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    guard (features[F.featureIdentifier]?.feature as? F)?.unload() ?? false else { return }
    features[F.featureIdentifier] = nil
  }
  
  public func isLoaded<F>(
    _ feature: F.Type
  ) -> Bool where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    return features[F.featureIdentifier]?.feature is F
  }
}

#if DEBUG
extension FeatureFactory {
  
  public static var autoLoadFeatures: Bool = true
  
  public func use<F>(
    _ feature: F,
    cancellables: Array<AnyCancellable> = .init()
  ) where F: Feature {
    featuresAccessLock.lock()
    assert(
      features[F.featureIdentifier] == nil,
      "Feature should not be replaced after initialization"
    )
    features[F.featureIdentifier] = FeatureInstance(
      feature: feature,
      cancellables: cancellables
    )
    featuresAccessLock.unlock()
  }
}

#endif

