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

// swiftlint:disable implicitly_unwrapped_optional
open class TestCase: XCTestCase {
  
  public var features: FeatureFactory!
  public var cancellables: Cancellables!
  public var environment: RootEnvironment {
    get { features.environment }
    set { features.environment = newValue }
  }
  
  override open class func setUp() {
    super.setUp()
    FeatureFactory.autoLoadFeatures = false
  }
  
  override open func setUp() {
    super.setUp()
    features = .init(environment: testEnvironment())
    features.use(Diagnostics.disabled)
    cancellables = .init()
  }
  
  override open func tearDown() {
    features = nil
    cancellables = nil
    super.tearDown()
  }
  
  public func testInstance<Controller: UIController>(
    _ type: Controller.Type = Controller.self,
    context: Controller.Context
  ) -> Controller {
    Controller.instance(
      in: context,
      with: features,
      cancellables: cancellables
    )
  }
  
  public func testInstance<Controller: UIController>(
    _ type: Controller.Type = Controller.self
  ) -> Controller
  where Controller.Context == Void {
    Controller.instance(
      in: Void(),
      with: features,
      cancellables: cancellables
    )
  }
  
  public func testInstance<F: Feature>(
    _ type: F.Type = F.self
  ) -> F {
    F.load(
      in: F.environmentScope(environment),
      using: features,
      cancellables: cancellables
    )
  }
}
