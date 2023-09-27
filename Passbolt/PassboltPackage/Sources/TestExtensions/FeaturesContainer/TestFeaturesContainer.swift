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

import FeatureScopes

@testable import Features

public final class TestFeaturesContainer {

  private var mocks: Dictionary<AnyHashable, Any>
  internal let cancellables: Cancellables  // for legacy elements
  private let lock: NSRecursiveLock

  internal init() {
    self.mocks = [  // initialize with Root scope
			RootFeaturesScope.identifier: RootFeaturesScope.self
    ]
    self.cancellables = .init()
    self.lock = .init()
  }
}

extension TestFeaturesContainer: FeaturesContainer {

  public func checkScope<Scope>(
    _: Scope.Type,
    file: StaticString,
    line: UInt
  ) -> Bool where Scope: FeaturesScope {
    self.withLock {
      self.mocks.keys
				.contains(Scope.identifier)
    }
  }

  public func ensureScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws where RequestedScope: FeaturesScope {
    try self.withLock {
			if self.mocks.keys.contains(RequestedScope.identifier) {
        // check passed
      }
      else {
        throw
          Unavailable
          .error(
            "Required scope is not available",
            file: file,
            line: line
          )
      }
    }
  }

  public func context<RequestedScope>(
    of scope: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws -> RequestedScope.Context
  where RequestedScope: FeaturesScope {
    try self.withLock {
			if let context: RequestedScope.Context = self.mocks[RequestedScope.identifier] as? RequestedScope.Context
      {
        return context
      }
      else {
        throw
          Unavailable
          .error(
            "Required scope context is not available",
            file: file,
            line: line
          )
      }
    }
  }

  public func branch<RequestedScope>(
    scope: RequestedScope.Type,
    context: RequestedScope.Context,
    file: StaticString,
    line: UInt
  ) -> FeaturesContainer
  where RequestedScope: FeaturesScope {
    self.withLock {
			self.mocks[RequestedScope.identifier] = context
    }
    return self
  }

  public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) -> Feature
  where Feature: StaticFeature {
    self.withLock {
			if let feature: Feature = self.mocks[Feature.identifier] as? Feature {
        return feature
      }
      else {
        return .placeholder
      }
    }
  }

  public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) throws -> Feature
  where Feature: LoadableFeature {
    try self.withLock {
      if let feature: Feature = self.mocks[Feature.identifier]
        as? Feature
      {
        return feature
      }
      else if let loader: FeatureLoader = self.mocks[Feature.identifier] as? FeatureLoader {
        guard let feature: Feature = try loader.load(self) as? Feature
        else { fatalError("Invalid feature type from loader!") }
        if loader.cache {
          self.mocks[Feature.identifier] = feature
        }  // else continue
        return feature
      }
      else {
        return .placeholder
      }
    }
  }
}

extension TestFeaturesContainer {

  @MainActor public func register<Feature>(
    _ register: (inout FeaturesRegistry) -> Void,
    for _: Feature.Type
  ) where Feature: LoadableFeature {
    var registry: FeaturesRegistry = .init()
    register(&registry)
    guard let loader: FeatureLoader = registry.findFeatureLoader(for: Feature.self)
    else { return XCTFail("Failed to register requested feature!") }
    self.withLock {
      self.mocks[Feature.identifier] = loader
    }
  }

  public func usePlaceholder<Feature>(
    for _: Feature.Type
  ) where Feature: LoadableFeature {
    self.withLock {
			precondition(!(self.mocks[Feature.identifier] is FeatureLoader))
      self.mocks[Feature.identifier] = Feature.placeholder
    }
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.withLock {
			precondition(!(self.mocks[Feature.identifier] is FeatureLoader))
			self.mocks[Feature.identifier] = Feature.placeholder
    }
  }

  public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: LoadableFeature {
    self.withLock {
			precondition(!(self.mocks[Feature.identifier] is FeatureLoader))
      var feature: Feature
      if let mocked: Feature = self.mocks[Feature.identifier]
        as? Feature
      {
        feature = mocked
      }
      else {
        feature = .placeholder
      }
      feature[keyPath: keyPath] = updated
      self.mocks[Feature.identifier] = feature
    }
  }

  public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: StaticFeature {
    self.withLock {
      precondition(!(self.mocks[Feature.identifier] is FeatureLoader))
      var feature: Feature
			if let mocked: Feature = self.mocks[Feature.identifier] as? Feature {
        feature = mocked
      }
      else {
        feature = .placeholder
      }
      feature[keyPath: keyPath] = updated
      self.mocks[Feature.identifier] = feature
    }
  }
}

extension TestFeaturesContainer {

  public func set<Scope>(
    _ scope: Scope.Type,
    context: Scope.Context
  ) where Scope: FeaturesScope {
    self.withLock {
			self.mocks[Scope.identifier] = context
    }
  }

  public func set<Scope>(
    _ scope: Scope.Type
  ) where Scope: FeaturesScope, Scope.Context == Void {
    self.withLock {
			self.mocks[Scope.identifier] = Void()
    }
  }
}

extension TestFeaturesContainer {

  @discardableResult
  fileprivate func withLock<Returned>(
    _ execute: () throws -> Returned
  ) rethrows -> Returned {
    self.lock.lock()
    defer { self.lock.unlock() }
    return try execute()
  }
}
