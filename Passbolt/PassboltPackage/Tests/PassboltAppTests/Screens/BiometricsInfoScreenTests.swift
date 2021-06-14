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
import Features
@testable import PassboltApp
import TestExtensions
import UIComponents

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
// swiftlint:disable implicitly_unwrapped_optional
// swiftlint:disable explicit_type_interface
final class BiometricsInfoScreenTests: TestCase {
  
  var biometry: Biometry!
  
  override func setUp() {
    super.setUp()
    biometry = .placeholder
  }
  
  override func tearDown() {
    biometry = nil
    super.tearDown()
  }
  
  func test_supportedBiometryType_isProvidedByBiometry() {
    biometry.supportedBiometryType = always(.touchID)
    features.use(biometry)
    let controller: BiometricsInfoController = testInstance()
    
    let result = controller.supportedBiometryType()
    
    XCTAssertEqual(result, .touchID)
  }
  
  func test_presentationDestinationPublisher_doesNotPublishByDefault() {
    features.use(biometry)
    
    let controller: BiometricsInfoController = testInstance()
    
    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)
    
    XCTAssertNil(result)
  }
  
  func test_presentationDestinationPublisher_publishExtensionSetup_afterSkip() {
    features.use(biometry)
    
    let controller: BiometricsInfoController = testInstance()
    
    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)
    
    controller.skipSetup()
    
    XCTAssertEqual(result, .extensionSetup)
  }
  
  func test_continueSetupPresentationPublisher_publishBiometrySetup_afterSetup() {
    features.use(biometry)
    
    let controller: BiometricsInfoController = testInstance()
    
    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)
    
    controller.setupBiometrics()
    
    XCTAssertEqual(result, .biometricsSetup)
  }
}

