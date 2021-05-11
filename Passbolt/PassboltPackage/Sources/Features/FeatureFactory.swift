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

import class Foundation.NSRecursiveLock

public final class FeatureFactory {
  
  #if DEBUG // debug builds allow change and access to environment for mocking and debug
  public var environment: RootEnvironment
  #else // production builds cannot access environment directly
  private let environment: RootEnvironment
  #endif
  private let featuresAccessLock: NSRecursiveLock = .init()
  private var features: Dictionary<ObjectIdentifier, Any> = .init()
  
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
    if let loaded: F = features[F.featureIdentifier] as? F {
      return loaded
    } else {
      let loaded: F = .load(
        in: F.environmentScope(environment),
        using: self
      )
      features[F.featureIdentifier] = loaded
      return loaded
    }
  }
  
  public func unload<F>(
    _ feature: F.Type
  ) where F: Feature {
    featuresAccessLock.lock()
    defer { featuresAccessLock.unlock() }
    guard (features[F.featureIdentifier] as? F)?.unload() ?? false else { return }
    features[F.featureIdentifier] = nil
  }
}

#if DEBUG
extension FeatureFactory {
  
  public func use<F>(
    _ feature: F
  ) where F: Feature {
    featuresAccessLock.lock()
    assert(
      features[F.featureIdentifier] == nil,
      "Feature should not be replaced after initialization"
    )
    features[F.featureIdentifier] = feature
    featuresAccessLock.unlock()
  }
}

#endif

