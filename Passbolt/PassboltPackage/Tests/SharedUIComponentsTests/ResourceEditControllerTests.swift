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

import Crypto
import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceEditControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    patch(
      \ResourceEditForm.fieldsPublisher,
       with: always(
        CurrentValueSubject(defaultResourceType.fields)
          .eraseToAnyPublisher()
       )
    )
    patch(
      \ResourceEditForm.fieldsPublisher,
       with: always(
        CurrentValueSubject(defaultResourceType.fields)
          .eraseToAnyPublisher()
       )
    )
  }

  func test_resourceFieldsPublisher_publishesFields() async throws {
    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .create(folderID: .none, uri: .none),
        completion: { _ in /* NOP */ }
      )
    )
    var result: OrderedSet<ResourceField> = .init()
    
    controller
      .resourcePropertiesPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { fields in
          result = fields
        }
      )
      .store(in: cancellables)
    
    XCTAssertEqual(
      result,
      defaultResourceType.fields
    )
  }

  func test_resourceFieldsPublisher_createsNewResourceInForm_whenCreatingNew() async throws {
    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .create(folderID: .none, uri: .none),
        completion: { _ in /* NOP */ }
      )
    )

    XCTAssertTrue(controller.createsNewResource)
  }

  func test_resourceFieldsPublisher_editsGivenResourceInForm_whenEditingExistingResource() async throws {
    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .edit(.mock_1),
        completion: { _ in /* NOP */ }
      )
    )

    XCTAssertFalse(controller.createsNewResource)
  }

  func test_generatePassword_generatesPassword_andTriggersFieldValuePublisher() async throws {
    var resultPassword: ResourceFieldValue { self.dynamicVariables.get(\.resultPassword)
    }
    var resultGenerate: (
      alphabet: Set<Set<Character>>,
      minLength: Int,
      targetEntropy: Entropy
    )? {
      self.dynamicVariables.get(\.resultGenerate)
    }

    patch(
      \ResourceEditForm.resource,
       with: always(.mock_1)
    )
    patch(
      \ResourceEditForm.setFieldValue,
       with: { (value: ResourceFieldValue, field: ResourceField) async throws -> Void in
         if field.name == "password" {
           self.dynamicVariables.set(\.resultPassword, to: value)
         }
         else {
           /* NOP */
         }
       }
    )
    patch(
      \RandomStringGenerator.generate,
       with: { alphabets, minLength, targetEntropy in
         self.dynamicVariables.set(
          \.resultGenerate,
           to: (alphabets, minLength, targetEntropy)
         )
         return "&!)]V3rYstrP@$word___"
       }
    )

    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .edit(.mock_1),
        completion: { _ in /* NOP */ }
      )
    )

    controller.generatePassword()

    await asyncExecutionControl.executeAll()

    XCTAssertNotNil(resultPassword)
    XCTAssertEqual(resultGenerate?.alphabet, CharacterSets.all)
    XCTAssertEqual(resultGenerate?.minLength, 18)
    XCTAssertEqual(resultGenerate?.targetEntropy, .veryStrongPassword)
  }

  func test_passwordEntropyPublisher_publishes_whenFieldPublisher_publishes() async throws {

    let fieldValueSubject: PassthroughSubject<Validated<ResourceFieldValue?>, Never> = .init()
    patch(
      \ResourceEditForm.validatedFieldValuePublisher,
       with: always(fieldValueSubject.eraseToAnyPublisher())
    )
    patch(
      \ResourceEditForm.resource,
       with: always(.mock_1)
    )
    patch(
      \RandomStringGenerator.entropy,
       with: always(.veryStrongPassword)
    )

    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .edit(.mock_1),
        completion: { _ in /* NOP */ }
      )
    )

    var result: Entropy?
    controller.passwordEntropyPublisher()
      .sink(
        receiveCompletion: { _ in
          XCTFail()
        },
        receiveValue: { entropy in
          result = entropy
        }
      )
      .store(in: cancellables)

    await asyncExecutionControl.executeAll()

    fieldValueSubject.send(.valid(.string("|hX!y*JLW@&&R3/Qo=Q?")))

    XCTAssertEqual(result, .veryStrongPassword)
  }

  func test_createResource_triggersRefreshIfNeeded_whenSendingFormSucceeds() async throws {
    var result: Void? {
      self.dynamicVariables.get(\.result)
    }

    patch(
      \SessionData.refreshIfNeeded,
       with: { () async throws in
         self.dynamicVariables.set(\.result, to: Void())
       }
    )

    patch(
      \ResourceEditForm.sendForm,
       with: always(.mock_1)
    )

    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .edit(.mock_1),
        completion: { _ in /* NOP */ }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_createResource_callsContextCompletionWithCreatedResourceID_whenSendingFormSucceeds() async throws {
    patch(
      \SessionData.refreshIfNeeded,
       with: always(Void())
    )
    patch(
        \ResourceEditForm.sendForm,
         with: always(.mock_1)
      )

    var result: Resource.ID?
    let controller: ResourceEditController = try testedInstance(
      context: (
        editing: .edit(.mock_1),
        completion: { result = $0 }
      )
    )

    try await controller
      .sendForm()
      .asAsyncValue()

    XCTAssertEqual(result, .mock_1)
  }
}

private let defaultResourceType: ResourceTypeDTO = .mock_1
