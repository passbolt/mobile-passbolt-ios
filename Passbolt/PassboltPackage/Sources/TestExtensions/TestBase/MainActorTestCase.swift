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

@available(*, deprecated, message: "Please switch to `LoadableFeatureTestCase`")
@MainActor
open class MainActorTestCase: TestCase {

  open override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    mainActorSetUp()
  }

  open func mainActorSetUp() {
    // to be overriden
  }

  open override func featuresActorTearDown() async throws {
    mainActorTearDown()
    try await super.featuresActorTearDown()
  }

  open func mainActorTearDown() {
    // to be overriden
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
