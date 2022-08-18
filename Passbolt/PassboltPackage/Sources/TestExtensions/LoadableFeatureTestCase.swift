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

import UIComponents
import XCTest

@testable import Features

/// Base class for preparing unit tests of features.
@MainActor open class LoadableFeatureTestCase<Feature>: AsyncTestCase
where Feature: LoadableFeature {

  open class var testedImplementation: FeatureLoader? {
    .none
  }

  open class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    fatalError("You have to override either `testedImplementation` or `testedImplementationRegister`")
  }

  private var mockedStaticFeatures: Dictionary<FeatureIdentifier, AnyFeature>!
  private var mockedDynamicFeatures: Dictionary<FeatureIdentifier, AnyFeature>!
  private var mockedEnvironment: AppEnvironment!
  private var featuresContainer: FeatureFactory!

  open func prepare() throws {
    // to override
  }

  // prevent overriding
  public final override func setUp() async throws {
    try await super.setUp()
    await Task { @MainActor in
      self.mockedStaticFeatures = .init()
      self.mockedDynamicFeatures = [
        FeatureIdentifier(
          featureTypeIdentifier: Diagnostics.typeIdentifier,
          featureContextIdentifier: ContextlessFeatureContext.instance.identifier
        ): Diagnostics.disabled
      ]
      self.mockedEnvironment = testEnvironment()
      self.mockedEnvironment.asyncExecutors = .immediate
      do {
        try self.prepare()
      }
      catch {
        XCTFail("\(error)")
      }
    }
    .waitForCompletion()
  }

  open func cleanup() throws {
    // to override
  }

  // prevent overriding
  public final override func tearDown() async throws {
    await Task { @MainActor in
      do {
        try self.cleanup()
      }
      catch {
        XCTFail("\(error)")
      }
      self.mockedStaticFeatures = .none
      self.mockedDynamicFeatures = .none
      self.mockedEnvironment = .none
      self.featuresContainer = .none
    }
    .waitForCompletion()
    try await super.tearDown()
  }

  // prevent overriding
  public final override func setUp() {
    super.setUp()
  }

  // prevent overriding
  public final override func setUpWithError() throws {
    try super.setUpWithError()
  }

  // prevent overriding
  public final override func tearDown() {
    super.tearDown()
  }
}

extension LoadableFeatureTestCase {

  public nonisolated final func testInstance(
    context: Feature.Context
  ) async throws -> Feature {
    try await self.features
      .instance(
        of: Feature.self,
        context: context
      )
  }

  public nonisolated final func testInstance() async throws -> Feature
  where Feature.Context == ContextlessFeatureContext {
    try await self.features
      .instance(
        of: Feature.self,
        context: ContextlessFeatureContext.instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature,
    context: MockFeature.Context
  ) where MockFeature: LoadableFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: MockFeature.typeIdentifier,
      featureContextIdentifier: context.identifier
    )
    self.mockedDynamicFeatures[identifier] = instance
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.use(
      instance,
      context: .instance
    )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: StaticFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: MockFeature.typeIdentifier,
      featureContextIdentifier: ContextlessFeatureContext.instance.identifier
    )
    self.mockedStaticFeatures[identifier] = instance
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LegacyFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: MockFeature.typeIdentifier,
      featureContextIdentifier: ContextlessFeatureContext.instance.identifier
    )
    self.mockedDynamicFeatures[identifier] = instance
  }

  public final func patch<Value>(
    environment keyPath: WritableKeyPath<AppEnvironment, Value>,
    with value: Value
  ) {
    self.mockedEnvironment[keyPath: keyPath] = value
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    context: MockFeature.Context,
    with value: Value
  ) where MockFeature: LoadableFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: MockFeature.typeIdentifier,
      featureContextIdentifier: context.identifier
    )
    var instance: MockFeature
    if let current: MockFeature = self.mockedDynamicFeatures[identifier] as? MockFeature {
      instance = current
    }
    else {
      instance = .placeholder
    }
    instance[keyPath: keyPath] = value
    self.mockedDynamicFeatures[identifier] = instance
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.patch(
      keyPath,
      context: .instance,
      with: value
    )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LegacyFeature {
    let identifier: FeatureIdentifier = .init(
      featureTypeIdentifier: MockFeature.typeIdentifier,
      featureContextIdentifier: ContextlessFeatureContext.instance.identifier
    )
    var instance: MockFeature
    if let current: MockFeature = self.mockedDynamicFeatures[identifier] as? MockFeature {
      instance = current
    }
    else {
      instance = .placeholder
    }
    instance[keyPath: keyPath] = value
    self.mockedDynamicFeatures[identifier] = instance
  }

  public func isCached<Feature>(
    _ featureType: Feature.Type,
    context: Feature.Context
  ) -> Bool
  where Feature: LoadableFeature {
    self.features
      .isCached(
        featureType,
        context: context
      )
  }

  public func isCached<Feature>(
    _ featureType: Feature.Type
  ) -> Bool
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.isCached(
      featureType,
      context: .instance
    )
  }
}

extension LoadableFeatureTestCase {

  @MainActor private var features: FeatureFactory {
    if let instance: FeatureFactory = self.featuresContainer {
      return instance
    }
    else {
      let instance: FeatureFactory = .init(
        environment: self.mockedEnvironment,
        autoLoadFeatures: false,
        allowScopes: false
      )
      instance.set(staticFeatures: self.mockedStaticFeatures)
      instance.set(dynamicFeatures: self.mockedDynamicFeatures)
      instance.use(  // overriden by mocked features, has to add it again
        EnvironmentLegacyBridge(
          environment: self.mockedEnvironment
        )
      )

      if let testedImplementation: FeatureLoader = Self.testedImplementation {
        instance.use(testedImplementation)
      }
      else {
        Self.testedImplementationRegister(instance)()
      }

      self.featuresContainer = instance
      return instance
    }
  }
}
