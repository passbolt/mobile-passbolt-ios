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
// swiftlint:disable implicitly_unwrapped_optional
final class CodeScanningScreenTests: XCTestCase {
  
  private var features: FeatureFactory!
  private var cancellables: Array<AnyCancellable>!
  
  override func setUp() {
    super.setUp()
    features = .init(environment: testEnvironment())
    cancellables = .init()
  }
  
  override func tearDown() {
    features = nil
    cancellables = nil
    super.tearDown()
  }
  
  func test_exitConfirmation_isPresented_whenCallingPresent() {
    let controller: CodeScanningController = .instance(with: features)
    var result: Bool!
    
    controller.exitConfirmationPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.presentExitConfirmation()
    
    XCTAssertTrue(result)
  }
  
  func test_exitConfirmation_isNotPresented_whenCallingDismiss() {
    let controller: CodeScanningController = .instance(with: features)
    var result: Bool!
    
    controller.exitConfirmationPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.dismissExitConfirmation()
    
    XCTAssertFalse(result)
  }
  
  func test_help_isPresented_whenCallingPresent() {
    let controller: CodeScanningController = .instance(with: features)
    var result: Bool!
    
    controller.helpPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.presentHelp()
    
    XCTAssertTrue(result)
  }
  
  func test_help_isNotPresented_whenCallingDismiss() {
    let controller: CodeScanningController = .instance(with: features)
    var result: Bool!
    
    controller.helpPresentationPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { presented in
        result = presented
      }
      .store(in: &cancellables)
    
    controller.dismissHelp()
    
    XCTAssertFalse(result)
  }
  
  func test_initialProgress_isNotEmptyAndNotFull() {
    let controller: CodeScanningController = .instance(with: features)
    var result: Double!
    
    controller.progressPublisher()
      .receive(on: ImmediateScheduler.shared)
      .sink { progress in
        result = progress
      }
      .store(in: &cancellables)
    
    XCTAssertGreaterThan(result, 0)
    XCTAssertLessThan(result, 1)
  }
  
  func test_progress_isUpdated_whenUpdatingSteps() {
    let controller: CodeScanningController = .instance(with: features)
    let steps: UInt = 6
    let completedSteps: UInt = 3
    var result: Double!
    
    controller.progressPublisher()
      .dropFirst()
      .receive(on: ImmediateScheduler.shared)
      .sink { progress in
        result = progress
      }
      .store(in: &cancellables)
    
    controller.updateProgress(steps: steps, completed: completedSteps)
    
    XCTAssertEqual(result, Double(completedSteps) / Double(steps))
  }
}
