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

/// Base class for preparing unit tests.
/// For testing UIComponents or other items
/// that require MainActor isolation please
/// use MainActorTestCase instead.
open class TestCase: XCTestCase {

  public var features: FeatureFactory!
  public var cancellables: Cancellables!
  @FeaturesActor public var environment: AppEnvironment {
    get { features.environment }
    set { features.environment = newValue }
  }

  final override public class func setUp() {
    super.setUp()
    FeaturesActor.execute {
      FeatureFactory.autoLoadFeatures = false
    }
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

  @FeaturesActor open func featuresActorSetUp() async throws {
    self.features = .init(environment: testEnvironment())
    self.features.use(Diagnostics.disabled)
    self.features.environment.asyncExecutors = .immediate
    self.cancellables = .init()
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

  @FeaturesActor open func featuresActorTearDown() async throws {
    self.features = nil
    self.cancellables = nil
  }

  public final func testInstance<F: Feature>(
    _ type: F.Type = F.self
  ) async throws -> F {
    try await F.load(
      in: environment,
      using: features,
      cancellables: cancellables
    )
  }
}
