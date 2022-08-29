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

import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceEditControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features
      .usePlaceholder(for: ResourceEditNetworkOperation.self)
    features
      .usePlaceholder(for: Resources.self)
    features
      .usePlaceholder(for: SessionData.self)
    features
      .usePlaceholder(for: RandomStringGenerator.self)
    features
      .patch(
        \ResourceEditForm.setEnclosingFolder,
        with: always(Void())
      )
  }

  func test_resourceFieldsPublisher_publishesFields() async throws {
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
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
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    var result: Resource.ID?
    let uncheckedSendableResult: UncheckedSendable<Resource.ID?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features
      .patch(
        \ResourceEditForm.editResource,
        with: { resourceID in
          uncheckedSendableResult.variable = resourceID
          return CurrentValueSubject(Void())
            .eraseToAnyPublisher()
        }
      )

    let _: ResourceEditController = try await testController(
      context: (
        .existing("resource-id"),
        completion: { _ in /* NOP */ }
      )
    )

    XCTAssertEqual(result, "resource-id")
  }

  func test_resourceFieldsPublisher_fails_whenEditingExistingResourceFails() async throws {
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.editResource,
        with: always(
          Fail(error: MockIssue.error())
            .eraseToAnyPublisher()
        )
      )

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
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.editResource,
        with: always(
          CurrentValueSubject(Void())
            .eraseToAnyPublisher()
        )
      )

    var resultPassword: ResourceFieldValue?
    let uncheckedSendableResultPassword: UncheckedSendable<ResourceFieldValue?> = .init(
      get: { resultPassword },
      set: { resultPassword = $0 }
    )
    features
      .patch(
        \ResourceEditForm.setFieldValue,
        with: { value, field in
          if field == .password {
            uncheckedSendableResultPassword.variable = value
          }
          else {
            /* NOP */
          }
          return Just(Void())
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
      )
    var resultGenerate:
      (
        alphabet: Set<Set<Character>>,
        minLength: Int,
        targetEntropy: Entropy
      )?
    let uncheckedSendableResultGenerate:
      UncheckedSendable<
        (
          alphabet: Set<Set<Character>>,
          minLength: Int,
          targetEntropy: Entropy
        )?
      > = .init(
        get: { resultGenerate },
        set: { resultGenerate = $0 }
      )
    features
      .patch(
        \RandomStringGenerator.generate,
        with: { alphabets, minLength, targetEntropy in
          uncheckedSendableResultGenerate.variable = (alphabets, minLength, targetEntropy)
          return "&!)]V3rYstrP@$word___"
        }
      )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
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
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.editResource,
        with: always(
          CurrentValueSubject(Void())
            .eraseToAnyPublisher()
        )
      )
    let fieldValueSubject: PassthroughSubject<Validated<ResourceFieldValue>, Never> = .init()
    features
      .patch(
        \ResourceEditForm.fieldValuePublisher,
        with: always(
          fieldValueSubject
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \RandomStringGenerator.entropy,
        with: always(.veryStrongPassword)
      )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
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
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.sendForm,
        with: always(
          Just("1")
            .eraseErrorType()
            .eraseToAnyPublisher()
        )
      )
    features.patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
        completion: { _ in /* NOP */ }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let isLoaded = features.isCached(ResourceEditForm.self)
    XCTAssertFalse(isLoaded)
  }

  func test_createResource_triggersRefreshIfNeeded_whenSendingFormSucceeds() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features.patch(
      \SessionData.refreshIfNeeded,
      with: {
        uncheckedSendableResult.variable = Void()
      }
    )
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.sendForm,
        with: always(
          Just("1")
            .eraseErrorType()
            .eraseToAnyPublisher()
        )
      )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
        completion: { _ in /* NOP */ }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_createResource_callsContextCompletionWithCreatedResourceID_whenSendingFormSucceeds() async throws {
    features.patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )
    features
      .patch(
        \ResourceEditForm.sendForm,
        with: always(
          Just("1")
            .eraseErrorType()
            .eraseToAnyPublisher()
        )
      )

    var result: Resource.ID?
    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
        completion: { id in result = id }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertEqual(result, "1")
  }

  func test_resourceForm_isUnloaded_whenCleanupCalled() async throws {
    features
      .patch(
        \ResourceEditForm.resourceTypePublisher,
        with: always(
          CurrentValueSubject(defaultResourceType)
            .eraseToAnyPublisher()
        )
      )

    let controller: ResourceEditController = try await testController(
      context: (
        .new(in: nil, url: .none),
        completion: { _ in /* NOP */ }
      )
    )

    controller.cleanup()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    let isLoaded = features.isCached(ResourceEditForm.self)
    XCTAssertFalse(isLoaded)
  }
}

private let defaultResourceType: ResourceTypeDTO = .random()
