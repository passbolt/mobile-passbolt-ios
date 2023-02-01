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

@testable import Features

public final class TestFeaturesContainer {

  private let state: CriticalState<Dictionary<MockItemKey, Any>>

  internal init() {
    self.state = .init(
      [  // initialize with Root scope
        .init(RootFeaturesScope.self): RootFeaturesScope.self
      ]
    )
  }
}

extension TestFeaturesContainer: FeaturesContainer {

  public func ensureScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws where RequestedScope: FeaturesScope {
    try self.state.access { state in
      if state.keys
        .contains(.init(RequestedScope.self))
      {
        // check passed
      }
      else {
        throw
          MockIssue
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
    try self.state.access { state in
      if let context: RequestedScope.Context = state[.init(RequestedScope.self)] as? RequestedScope.Context {
        return context
      }
      else {
        throw
          MockIssue
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
    self.state.access { state in
      state[.init(RequestedScope.self)] = context
    }
    return self
  }

  public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) -> Feature
  where Feature: StaticFeature {
    self.state.access { state in
      if let feature: Feature = state[.init(Feature.self)] as? Feature {
        return feature
      }
      else {
        return .placeholder
      }
    }
  }

  public func instance<Feature>(
    of featureType: Feature.Type,
    context: Feature.Context,
    file: StaticString,
    line: UInt
  ) throws -> Feature
  where Feature: LoadableFeature {
    self.state.access { state in
      if let feature: Feature = state[.init(Feature.self, context.identifier)] as? Feature {
        return feature
      }
      else {
        return .placeholder
      }
    }
  }
}

extension TestFeaturesContainer {

  public func usePlaceholder<Feature>(
    for _: Feature.Type,
    context: Feature.Context
  ) where Feature: LoadableFeature {
    self.state.access { state in
      state[.init(Feature.self, context.identifier)] = Feature.placeholder
    }
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.state.access { state in
      state[.init(Feature.self)] = Feature.placeholder
    }
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.state.access { state in
      state[.init(Feature.self)] = Feature.placeholder
    }
  }

  public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    context: Feature.Context,
    with updated: Property
  ) where Feature: LoadableFeature {
    self.state.access { state in
      var feature: Feature
      if let mocked: Feature = state[.init(Feature.self, context.identifier)] as? Feature {
        feature = mocked
      }
      else {
        feature = .placeholder
      }
      feature[keyPath: keyPath] = updated
      state[.init(Feature.self, context.identifier)] = feature
    }
  }

  public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.state.access { state in
      var feature: Feature
      if let mocked: Feature = state[.init(Feature.self)] as? Feature {
        feature = mocked
      }
      else {
        feature = .placeholder
      }
      feature[keyPath: keyPath] = updated
      state[.init(Feature.self)] = feature
    }
  }

  public func patch<Feature, Property>(
    _ keyPath: WritableKeyPath<Feature, Property>,
    with updated: Property
  ) where Feature: StaticFeature {
    self.state.access { state in
      var feature: Feature
      if let mocked: Feature = state[.init(Feature.self)] as? Feature {
        feature = mocked
      }
      else {
        feature = .placeholder
      }
      feature[keyPath: keyPath] = updated
      state[.init(Feature.self)] = feature
    }
  }
}

extension TestFeaturesContainer {

  internal func set(
    _ items: Dictionary<MockItemKey, Any>
  ) {
    self.state.access { state in
      state.merge(items, uniquingKeysWith: { $1 })
    }
  }

  public func set<Scope>(
    _ scope: Scope.Type,
    context: Scope.Context
  ) where Scope: FeaturesScope {
    self.state.access { state in
      state[.init(Scope.self)] = context
    }
  }

  public func set<Scope>(
    _ scope: Scope.Type
  ) where Scope: FeaturesScope, Scope.Context == Void {
    self.state.access { state in
      state[.init(Scope.self)] = Void()
    }
  }
}

internal struct MockItemKey {

  private let identifier: AnyHashable
  private let additionalIdentifier: AnyHashable

  internal init<T>(
    _: T.Type
  ) {
    self.identifier = ObjectIdentifier(T.self)
    self.additionalIdentifier = ContextlessFeatureContext.instance.identifier
  }

  internal init<T>(
    _: T.Type,
    _ additional: AnyHashable
  ) {
    self.identifier = ObjectIdentifier(T.self)
    self.additionalIdentifier = additional
  }
}

extension MockItemKey: Hashable {}
