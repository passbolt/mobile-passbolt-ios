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

@testable import Accounts
import Combine
import Features
import NetworkClient
@testable import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceCreateControllerTests: TestCase {

  private var networkClient: NetworkClient!
  private var resources: Resources!
  private var resourceForm: ResourceCreateForm!
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
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )

    features.use(resources)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceCreateController = testInstance()
    var result: Array<ResourceCreateController.Field> = .init()

    controller.resourceFieldsPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { fields in
          result = fields
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, [
      .name(required: true, encrypted: false, maxLength: nil),
      .uri(required: false, encrypted: false, maxLength: nil),
      .username(required: false, encrypted: false, maxLength: nil),
      .password(required: true, encrypted: true, maxLength: nil),
      .description(required: false, encrypted: true, maxLength: nil)
    ])
  }

  func test_generatePassword_generatesPassword_andTriggersFieldValuePublisher() {
    var resultPassword: String?
    resourceForm.resourceTypePublisher = always(
      Just(defaultResourceType)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.setFieldValue = { value, fieldName in
      if fieldName == "password" {
        resultPassword = value
      }
      else {
        /* NOP */
      }
      return Just(Void())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    var resultGenerate: (
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

    let controller: ResourceCreateController = testInstance()

    controller.generatePassword()

    XCTAssertNotNil(resultPassword)
    XCTAssertEqual(resultGenerate?.alphabet, CharacterSets.all)
    XCTAssertEqual(resultGenerate?.minLength, 18)
    XCTAssertEqual(resultGenerate?.targetEntropy, .veryStrongPassword)
  }

  func test_passwordEntropyPublisher_publishes_whenFieldPublisher_publishes() {
    let fieldValueSubject: PassthroughSubject<Validated<String>, Never> = .init()
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

    let controller: ResourceCreateController = testInstance()
    var result: Entropy?

    controller.passwordEntropyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { entropy in
          result = entropy
        }
      )
      .store(in: cancellables)

    fieldValueSubject.send(.valid("|hX!y*JLW@&&R3/Qo=Q?"))

    XCTAssertEqual(result, .veryStrongPassword)
  }

  func test_createResource_triggersRefreshIfNeeded_andUnloadsResourceCreateForm() {
    var refreshIfNeededCalled: Void?
    var unloadFeature: Void?
    resources.refreshIfNeeded = {
      refreshIfNeededCalled = Void()
      return Empty(completeImmediately: true)
        .eraseToAnyPublisher()
    }
    resourceForm.createResource = always(
      Just("1")
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resourceForm.featureUnload = {
      unloadFeature = Void()
      return true
    }
    features.use(resources)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceCreateController = testInstance()

    controller.createResource()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(refreshIfNeededCalled)
    XCTAssertNotNil(unloadFeature)
  }

  func test_resourceForm_isUnloaded_whenCleanupCalled() {
    resourceForm.featureUnload = always(true)

    features.use(resources)
    features.use(resourceForm)
    features.use(randomGenerator)

    let controller: ResourceCreateController = testInstance()

    controller.cleanup()

    XCTAssertFalse(features.isLoaded(ResourceCreateForm.self))
  }
}

private let defaultResourceType: ResourceType = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .string(name: "name", required: true, encrypted: false, maxLength: nil),
    .string(name: "uri", required: false, encrypted: false, maxLength: nil),
    .string(name: "username", required: false, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "description", required: false, encrypted: true, maxLength: nil)
  ]
)
