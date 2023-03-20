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

import Display
import Features
import XCTest

@MainActor
open class FeaturesTestCase: XCTestCase {

  private lazy var testFeatures: TestFeaturesContainer = .init()
  public let asyncExecutionControl: AsyncExecutor.MockExecutionControl = .init()
  public let dynamicVariables: DynamicVariables = .init()

  open func commonPrepare() {
    patch(
      \OSDiagnostics.self,
      with: .disabled
    )
    patch(
      \AsyncExecutor.self,
      with: .mock(self.asyncExecutionControl)
    )
  }

  final override public class func setUp() {
    super.setUp()
  }

  public final override func setUp() {
    /* NOP - overrding to ignore calls from default setUp methods calling order */
  }

  public final override func setUp() async throws {
    // casting to specify correct method to be called,
    // by default async one is selected by the compiler
    (super.setUp as () -> Void)()
    try await super.setUp()
    self.commonPrepare()
  }

  public final override func tearDown() {
    /* NOP - overrding to ignore calls from default tearDown methods calling order */
  }

  public final override func tearDown() async throws {
    try await super.tearDown()
    // casting to specify correct method to be called,
    // by default async one is selected by the compiler
    (super.tearDown as () -> Void)()
    XCTAssertEqual(
      self.asyncExecutionControl.scheduledTasksCount,
      0,
      "All scheduled async tasks should be finished."
    )
  }
}

extension FeaturesTestCase {

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self,
    context: Feature.Context
  ) throws -> Feature
  where Feature: LoadableFeature {
    try self.testFeatures
      .instance(
        of: featureType,
        context: context
      )
  }

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    try self.testFeatures
      .instance(
        of: featureType
      )
  }

  public final func testedInstance<Alert>(
    _ alertType: Alert.Type = Alert.self,
    context: Alert.Context
  ) throws -> Alert
  where Alert: AlertController {
    try Alert(
      with: context,
      using: self.testFeatures
    )
  }

  public final func testedInstance<Alert>(
    _ alertType: Alert.Type = Alert.self
  ) throws -> Alert
  where Alert: AlertController, Alert.Context == Void {
    try Alert(
      with: Void(),
      using: self.testFeatures
    )
  }
}

extension FeaturesTestCase {

  public func set<Scope>(
    _ scope: Scope.Type,
    context: Scope.Context
  ) where Scope: FeaturesScope {
    self.testFeatures
      .set(
        scope,
        context: context
      )
  }

  public func set<Scope>(
    _ scope: Scope.Type
  ) where Scope: FeaturesScope, Scope.Context == Void {
    self.testFeatures
      .set(scope)
  }

  public func usePlaceholder<Feature>(
    for _: Feature.Type,
    context: Feature.Context
  ) where Feature: LoadableFeature {
    self.testFeatures
      .usePlaceholder(
        for: Feature.self,
        context: context
      )
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.testFeatures
      .usePlaceholder(for: Feature.self)
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.testFeatures
      .usePlaceholder(for: Feature.self)
  }

  public final func use<MockFeature>(
    _ instance: MockFeature,
    context: MockFeature.Context
  ) where MockFeature: LoadableFeature {
    self.testFeatures
      .patch(
        \MockFeature.self,
        context: context,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.testFeatures
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: StaticFeature {
    self.testFeatures
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    context: MockFeature.Context,
    with value: Value
  ) where MockFeature: LoadableFeature {
    self.testFeatures
      .patch(
        keyPath,
        context: context,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.testFeatures
      .patch(
        keyPath,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: StaticFeature {
    self.testFeatures
      .patch(
        keyPath,
        with: value
      )
  }
}
