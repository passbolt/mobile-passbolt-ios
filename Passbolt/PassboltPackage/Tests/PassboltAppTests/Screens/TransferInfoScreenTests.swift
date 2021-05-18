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
import OSIntegration
@testable import PassboltApp
import TestExtensions
import UIComponents
import XCTest

// swiftlint:disable explicit_acl
// swiftlint:disable explicit_top_level_acl
// swiftlint:disable implicitly_unwrapped_optional
final class TransferInfoScreenTests: XCTestCase {

  private var features: FeatureFactory!
  private var cancellables: Array<AnyCancellable>!
  
  override func setUp() {
    super.setUp()
    #warning("TODO: use `FeatureFactory.autoLoadFeatures = false`")
    features = .init(environment: testEnvironment())
    cancellables = .init()
  }
  
  override func tearDown() {
    features = nil
    cancellables = nil
    super.tearDown()
  }
  
  func test_noCameraPermissionAlert_isPresented_whenCallingPresent() {
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.presentNoCameraPermissionAlertPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.presentNoCameraPermissionAlert()
    
    XCTAssertTrue(result)
  }
  
  func test_noCameraPermissionAlert_isDismissed_whenCallingDismiss() {
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.presentNoCameraPermissionAlertPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.dismissNoCameraPermissionAlert()
    
    XCTAssertFalse(result)
  }
  
  func test_showSettings_isTriggered_whenCallingShowSettings() {
    var result: Void?
    
    features.environment.urlOpener.openAppSettings = {
      result = ()
      return Just(true).eraseToAnyPublisher()
    }
    
    let controller: TransferInfoCameraRequiredAlertController = .instance(with: features)
    
    controller.showSettings()
    
    XCTAssertNotNil(result)
  }
  
  func test_cameraPermission_isRequested_andDenied_whenPermissionIsNotDetermined() {
    features.environment.camera.checkPermission = {
      Just(.notDetermined).eraseToAnyPublisher()
    }
    
    features.environment.camera.requestPermission = {
      Just(false).eraseToAnyPublisher()
    }
    
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.requestOrNavigatePublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { granted in
        result = granted
      }
      .store(in: &cancellables)
    
    XCTAssertFalse(result)
  }
  
  func test_cameraPermission_isRequested_andGranted_whenPermissionIsNotDetermined() {
    features.environment.camera.checkPermission = {
      Just(.notDetermined).eraseToAnyPublisher()
    }
    
    features.environment.camera.requestPermission = {
      Just(true).eraseToAnyPublisher()
    }
    
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.requestOrNavigatePublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { granted in
        result = granted
      }
      .store(in: &cancellables)
    
    XCTAssertTrue(result)
  }
  
  func test_cameraPermission_isNotRequested_whenPermissionIsAlreadyDenied() {
    features.environment.camera.checkPermission = {
      Just(.denied).eraseToAnyPublisher()
    }
    
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.requestOrNavigatePublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { granted in
        result = granted
      }
      .store(in: &cancellables)
    
    XCTAssertFalse(result)
  }
  
  func test_cameraPermission_isAlreadyGranted_whenPermissionIsAuthorized() {
    features.environment.camera.checkPermission = { Just(.authorized).eraseToAnyPublisher() }
    
    let controller: TransferInfoScreenController = .instance(with: features)
    var result: Bool!
    
    controller.requestOrNavigatePublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { granted in
        result = granted
      }
      .store(in: &cancellables)
    
    XCTAssertTrue(result)
  }
}
