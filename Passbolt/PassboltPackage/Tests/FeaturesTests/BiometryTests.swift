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

import TestExtensions

@testable import Features

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class BiometryTests: TestCase {

  func test_biometricsStatePublisher_publishesBiometricsState_initially() async throws {
    try await FeaturesActor.execute {
      self.environment.biometrics.checkBiometricsState = always(.configuredTouchID)
      self.environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    }

    let feature: Biometry = try await testInstance()

    var result: Biometrics.State!
    feature
      .biometricsStatePublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertEqual(result, .configuredTouchID)
  }

  func
    test_biometricsStatePublisher_publishesBiometricsStateAgain_afterPickingApplicationFromBackground_whenStateDoesNotChange()
    async throws
  {
    var biometricsState: Biometrics.State = .configuredTouchID
    try await FeaturesActor.execute {
      self.environment.biometrics.checkBiometricsState = always(biometricsState)
      self.environment.appLifeCycle.lifeCyclePublisher = always(
        [
          AppLifeCycle.Transition.didEnterBackground,
          AppLifeCycle.Transition.didBecomeActive,
        ]
        .publisher
        // lifeCyclePublisher is used in Biometry instance creation
        // it publishes immediately after creating so delaying for test case
        .delay(for: 0.1, scheduler: RunLoop.main)
        .handleEvents(receiveOutput: { _ in biometricsState = .configuredFaceID })
        .eraseToAnyPublisher()
      )
    }

    let feature: Biometry = try await testInstance()
    let expectation: XCTestExpectation = .init()
    var result: Array<Biometrics.State> = .init()
    feature
      .biometricsStatePublisher()
      .sink {
        result.append($0)
        guard result.count == 2 else { return }
        expectation.fulfill()
      }
      .store(in: cancellables)
    wait(for: [expectation], timeout: 0.3)
    XCTAssertEqual(result, [.configuredTouchID, .configuredFaceID])
  }

  func
    test_biometricsStatePublisher_publishesBiometricsStateOnce_afterPickingApplicationFromBackground_whenStateChanges()
    async throws
  {
    try await FeaturesActor.execute {
      self.environment.biometrics.checkBiometricsState = always(.configuredTouchID)
      self.environment.appLifeCycle.lifeCyclePublisher = always(
        [
          AppLifeCycle.Transition.didEnterBackground,
          AppLifeCycle.Transition.didBecomeActive,
        ]
        .publisher
        // lifeCyclePublisher is used in Biometry instance creation
        // it publishes immediately after creating so delaying for test case
        .delay(for: 0.1, scheduler: RunLoop.main)
        .eraseToAnyPublisher()
      )
    }

    let feature: Biometry = try await testInstance()
    let expectation: XCTestExpectation = .init()
    var result: Array<Biometrics.State> = .init()
    feature
      .biometricsStatePublisher()
      .sink {
        result.append($0)
        guard result.count == 1 else { return }
        expectation.fulfill()
      }
      .store(in: cancellables)
    wait(for: [expectation], timeout: 0.3)
    XCTAssertEqual(result, [.configuredTouchID])
  }

  func test_biometricsStatePublisher_publishesConfiguredTouchID_whenBiometricsStateIsConfiguredTouchID() async throws {
    try await FeaturesActor.execute {
      self.environment.biometrics.checkBiometricsState = always(.configuredTouchID)
      self.environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    }

    let feature: Biometry = try await testInstance()

    var result: Biometrics.State!
    feature
      .biometricsStatePublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertEqual(result, .configuredTouchID)
  }

  func test_biometricsStatePublisher_publishesConfiguredFaceID_whenBiometricsStateIsConfiguredFaceID() async throws {
    try await FeaturesActor.execute {
      self.environment.biometrics.checkBiometricsState = always(.configuredFaceID)
      self.environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    }

    let feature: Biometry = try await testInstance()

    var result: Biometrics.State!
    feature
      .biometricsStatePublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertEqual(result, .configuredFaceID)
  }
}
