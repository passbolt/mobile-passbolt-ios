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
import CommonModels
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceEditControllerTests: MainActorTestCase {

  private var networkClient: NetworkClient!
  private var resources: Resources!
  private var resourceForm: ResourceEditForm!
  private var randomGenerator: RandomStringGenerator!

  override func mainActorSetUp() {
    networkClient = .placeholder
    resources = .placeholder
    resourceForm = .placeholder
    resourceForm.setEnclosingFolder = always(Void())
    randomGenerator = .placeholder
    resourceForm.featureUnload = always(Void())
  }

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.features.usePlaceholder(for: AccountSessionData.self)
  }

  override func mainActorTearDown() {
    networkClient = nil
    resources = nil
    resourceForm = nil
    randomGenerator = nil
  }

  func test_resourceFieldsPublisher_publishesFields() async throws {
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )
    var result: Array<ResourceFieldName> = .init()

    controller
      .resourcePropertiesPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { fields in
          result = fields.map(\.name)
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(
      result,
      defaultResourceType.fields.map(\.name)
    )
  }

  func test_resourceFieldsPublisher_editsGivenResourceInForm_whenEditingExistingResource() async throws {
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    var result: Resource.ID?
    resourceForm.editResource = { resourceID in
      result = resourceID
      return Just(Void())
        .eraseErrorType()
        .eraseToAnyPublisher()
    }
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let _: ResourceEditController = try await testController(
      context: (
        .existing("resource-id"),
        completion: { _ in /* NOP */ }
      )
    )

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceFieldsPublisher_fails_whenEditingExistingResourceFails() async throws {
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    resourceForm.editResource = always(
      Fail(error: MockIssue.error()).eraseToAnyPublisher()
    )
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .existing("resource-id"),
        completion: { _ in /* NOP */ }
      )
    )
    var result: Error?

    controller
      .resourcePropertiesPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_generatePassword_generatesPassword_andTriggersFieldValuePublisher() async throws {
    var resultPassword: ResourceFieldValue?
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.setFieldValue = { value, field in
      if field == .password {
        resultPassword = value
      }
      else {
        /* NOP */
      }
      return Just(Void())
        .eraseErrorType()
        .eraseToAnyPublisher()
    }
    var resultGenerate:
      (
        alphabet: Set<Set<Character>>,
        minLength: Int,
        targetEntropy: Entropy
      )?
    randomGenerator.generate = { alphabets, minLength, targetEntropy in
      resultGenerate = (alphabets, minLength, targetEntropy)
      return "&!)]V3rYstrP@$word___"
    }
    await features.use(resources)
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )

    controller.generatePassword()

    XCTAssertNotNil(resultPassword)
    XCTAssertEqual(resultGenerate?.alphabet, CharacterSets.all)
    XCTAssertEqual(resultGenerate?.minLength, 18)
    XCTAssertEqual(resultGenerate?.targetEntropy, .veryStrongPassword)
  }

  func test_passwordEntropyPublisher_publishes_whenFieldPublisher_publishes() async throws {
    let fieldValueSubject: PassthroughSubject<Validated<ResourceFieldValue>, Never> = .init()
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.fieldValuePublisher = always(
      fieldValueSubject.eraseToAnyPublisher()
    )
    randomGenerator.entropy = always(.veryStrongPassword)
    await features.use(resources)
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )
    var result: Entropy?

    controller.passwordEntropyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { entropy in
          result = entropy
        }
      )
      .store(in: cancellables)

    fieldValueSubject.send(.valid(.string("|hX!y*JLW@&&R3/Qo=Q?")))

    XCTAssertEqual(result, .veryStrongPassword)
  }

  func test_createResource_unloadsResourceEditForm_whenSendingFormSucceeds() async throws {
    var result: Void?
    await features.patch(
      \AccountSessionData.refreshIfNeeded,
      with: always(Void())
    )
    resourceForm.sendForm = always(
      Just("1")
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {
      result = Void()
    }
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_createResource_triggersRefreshIfNeeded_whenSendingFormSucceeds() async throws {
    var result: Void?
    await features.patch(
      \AccountSessionData.refreshIfNeeded,
      with: {
        result = Void()
      }
    )
    resourceForm.sendForm = always(
      Just("1")
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {}
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_createResource_callsContextCompletionWithCreatedResourceID_whenSendingFormSucceeds() async throws {
    await features.patch(
      \AccountSessionData.refreshIfNeeded,
      with: always(Void())
    )
    resourceForm.sendForm = always(
      Just("1")
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {}
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    await features.use(resourceForm)
    await features.use(randomGenerator)

    var result: Resource.ID?
    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { id in result = id }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertEqual(result, "1")
  }

  func test_resourceForm_isUnloaded_whenCleanupCalled() async throws {
    await features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = always(Void())
    await features.use(resourceForm)
    await features.use(randomGenerator)

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil),
        completion: { _ in /* NOP */ }
      )
    )

    controller.cleanup()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

    let isLoaded = await features.isLoaded(ResourceEditForm.self)
    XCTAssertFalse(isLoaded)
  }
}

private let defaultResourceType: ResourceTypeDTO = .random()
