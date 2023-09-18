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

import Features
import UIComponents
import XCTest

@available(iOS, introduced: 16.0.0, deprecated, message: "Please switch to `LoadableFeatureTestCase`")
@MainActor
open class MainActorTestCase: AsyncTestCase {

  public var features: TestFeaturesContainer!
  public var cancellables: Cancellables!
  public var mockExecutionControl: AsyncExecutor.MockExecutionControl!

  open func mainActorSetUp() {
    // to be overriden
  }

  open func mainActorTearDown() {
    // to be overriden
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
    try await featuresActorSetUp()
  }

  open func featuresActorSetUp() async throws {
    self.mockExecutionControl = .init()
    self.features = .init()
    self.features
      .patch(
        \AsyncExecutor.self,
        with: .mock(self.mockExecutionControl)
      )
    self.cancellables = .init()
    self.mainActorSetUp()
  }

  public final override func tearDown() {
    /* NOP - overrding to ignore calls from default tearDown methods calling order */
  }

  public final override func tearDown() async throws {
    try await featuresActorTearDown()
    try await super.tearDown()
    // casting to specify correct method to be called,
    // by default async one is selected by the compiler
    (super.tearDown as () -> Void)()
  }

  open func featuresActorTearDown() async throws {
    self.mainActorTearDown()
    self.features = nil
    self.cancellables = nil
    self.mockExecutionControl = nil
  }

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self,
    context: Feature.Context
  ) throws -> Feature
  where Feature: LoadableFeature {
    try features
      .instance(
        of: featureType,
        context: context
      )
  }

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == Void {
    try features
      .instance(
        of: featureType
      )
  }

  public final func testController<Controller: UIController>(
    _ type: Controller.Type = Controller.self,
    context: Controller.Context
  ) throws -> Controller {
    var features: Features = self.features
    return try Controller.instance(
      in: context,
      with: &features,
      cancellables: cancellables
    )
  }

  public final func testController<Controller: UIController>(
    _ type: Controller.Type = Controller.self
  ) throws -> Controller
  where Controller.Context == Void {
    var features: Features = self.features
    return try Controller.instance(
      in: Void(),
      with: &features,
      cancellables: cancellables
    )
  }
}
