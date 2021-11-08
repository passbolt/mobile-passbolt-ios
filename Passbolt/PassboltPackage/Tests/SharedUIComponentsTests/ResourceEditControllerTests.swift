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
import CommonDataModels
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceEditControllerTests: TestCase {

  private var networkClient: NetworkClient!
  private var resources: Resources!
  private var resourceForm: ResourceEditForm!
  private var randomGenerator: RandomStringGenerator!

  override func setUp() {
    super.setUp()

    networkClient = .placeholder
    resources = .placeholder
    resourceForm = .placeholder
    randomGenerator = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    networkClient = nil
    resources = nil
    resourceForm = nil
    randomGenerator = nil
  }

  func test_resourceFieldsPublisher_publishesFields() {
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { _ in /* NOP */ }
      )
    )
    var result: Array<ResourceField> = .init()

    controller
      .resourcePropertiesPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { fields in
          result = fields.map(\.field)
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(
      result,
      [
        .name,
        .uri,
        .username,
        .password,
        .description,
      ]
    )
  }

  func test_resourceFieldsPublisher_editsGivenResourceInForm_whenEditingExistingResource() {
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    var result: Resource.ID?
    resourceForm.editResource = { resourceID in
      result = resourceID
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(resourceForm)
    features.use(randomGenerator)

    let _: ResourceEditController = testInstance(
      context: (
        editedResource: "resource-id",
        completion: { _ in /* NOP */ }
      )
    )

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceFieldsPublisher_fails_whenEditingExistingResourceFails() {
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      CurrentValueSubject(defaultResourceType)
        .eraseToAnyPublisher()
    )
    resourceForm.editResource = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: "resource-id",
        completion: { _ in /* NOP */ }
      )
    )
    var result: TheError?

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

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_generatePassword_generatesPassword_andTriggersFieldValuePublisher() {
    var resultPassword: ResourceFieldValue?
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
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
        .setFailureType(to: TheError.self)
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
    features.use(resources)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { _ in /* NOP */ }
      )
    )

    controller.generatePassword()

    XCTAssertNotNil(resultPassword)
    XCTAssertEqual(resultGenerate?.alphabet, CharacterSets.all)
    XCTAssertEqual(resultGenerate?.minLength, 18)
    XCTAssertEqual(resultGenerate?.targetEntropy, .veryStrongPassword)
  }

  func test_passwordEntropyPublisher_publishes_whenFieldPublisher_publishes() {
    let fieldValueSubject: PassthroughSubject<Validated<ResourceFieldValue>, Never> = .init()
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.fieldValuePublisher = always(
      fieldValueSubject.eraseToAnyPublisher()
    )
    randomGenerator.entropy = always(.veryStrongPassword)
    features.use(resources)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
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

  func test_createResource_unloadsResourceEditForm_whenSendingFormSucceeds() {
    var result: Void?
    resources.refreshIfNeeded = {
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    resourceForm.sendForm = always(
      Just("1")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {
      result = Void()
      return true
    }
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { _ in /* NOP */ }
      )
    )

    controller
      .sendForm()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createResource_triggersRefreshIfNeeded_whenSendingFormSucceeds() {
    var result: Void?
    resources.refreshIfNeeded = {
      result = Void()
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    resourceForm.sendForm = always(
      Just("1")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {
      true
    }
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { _ in /* NOP */ }
      )
    )

    controller
      .sendForm()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_createResource_callsContextCompletionWithCreatedResourceID_whenSendingFormSucceeds() {
    resources.refreshIfNeeded = {
      Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    resourceForm.sendForm = always(
      Just("1")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = { true }
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resourceForm)
    features.use(randomGenerator)

    var result: Resource.ID?
    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { id in result = id }
      )
    )

    controller
      .sendForm()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, "1")
  }

  func test_resourceForm_isUnloaded_whenCleanupCalled() {
    features.use(resources)
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = always(true)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceEditController = testInstance(
      context: (
        editedResource: nil,
        completion: { _ in /* NOP */ }
      )
    )

    controller.cleanup()

    XCTAssertFalse(features.isLoaded(ResourceEditForm.self))
  }
}

private let defaultResourceType: ResourceType = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .init(name: "name", typeString: "string", required: true, encrypted: false, maxLength: nil)!,
    .init(name: "uri", typeString: "string", required: false, encrypted: false, maxLength: nil)!,
    .init(name: "username", typeString: "string", required: false, encrypted: false, maxLength: nil)!,
    .init(name: "password", typeString: "string", required: true, encrypted: true, maxLength: nil)!,
    .init(name: "description", typeString: "string", required: false, encrypted: true, maxLength: nil)!,
  ]
)
