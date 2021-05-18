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
import Combine
@testable import PassboltApp
import TestExtensions
import UIComponents
import XCTest

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
final class WelcomeScreenTests: XCTestCase {
  
  // swiftlint:disable implicitly_unwrapped_optional
  private var factory: FeatureFactory!
  private var cancellables: Array<AnyCancellable>!
  
  override class func setUp() {
    super.setUp()
    FeatureFactory.autoLoadFeatures = false
  }
  
  override func setUp() {
    super.setUp()
    factory = .init(environment: testEnvironment())
    cancellables = .init()
  }
  
  override func tearDown() {
    factory = nil
    cancellables = nil
    super.tearDown()
  }
  
  func test_noAccountAlertAppears_whenTapped_Succeeds() {
    let controller: WelcomeScreenController = .instance(with: factory)
    var result: Bool!
    
    controller.noAccountAlertPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.presentNoAccountAlert()
    
    XCTAssertTrue(result)
  }
  
  func test_noAccountAlertDisappears_whenDissmissed_Succeeds() {
    let controller: WelcomeScreenController = .instance(with: factory)
    var result: Bool!
    
    controller.noAccountAlertPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.dismissNoAccountAlert()
    
    XCTAssertFalse(result)
  }
  
  func test_navigateToNextScreen_whenTriggered_Succeeds() {
    let controller: WelcomeScreenController = .instance(with: factory)
    var result: Void?
    
    controller.pushTransferInfoPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink {
        result = ()
      }
      .store(in: &cancellables)
    
    controller.pushTransferInfo()
    
    XCTAssertNotNil(result)
  }
}
