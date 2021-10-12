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

import Commons
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceCreateFormTests: TestCase {

  var database: AccountDatabase!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()
    database = .placeholder
    networkClient = .placeholder
  }

  override func tearDown() {
    database = nil
    networkClient = nil
    super.tearDown()
  }

  func test_resourceTypePublisher_fails_whenNoResourceTypesAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_resourceTypePublisher_fails_whenNoValidResourceTypeAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([emptyResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_resourceTypePublisher_publishesDefaultResourceType_whenValidResourceTypeAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([.init(id: "password-and-description", slug: "password-and-description", name: "password-and-description", fields: [])]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: ResourceType?
    feature
      .resourceTypePublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { resourceType in
          result = resourceType
        }
      )
      .store(in: cancellables)

    XCTAssert(result?.isDefault ?? false)
  }

  func test_fieldValuePublisher_returnsNotPublishingPublisher_whenResourceFieldNotAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: Void?
    feature
      .fieldValuePublisher("unavailable")
      .sink(
        receiveCompletion: { completion in
          result = Void()
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_fieldValuePublisher_returnsInitiallyPublishingPublisher_whenResourceFieldAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.value, "")
  }

  func test_fieldValuePublisher_returnsPublisherPublishingChages_whenResourceFieldValueChanges() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    feature
      .setFieldValue("updated", "name")
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.value, "updated")
  }

  func test_fieldValuePublisher_returnsPublisherPublishingValidatedValue_withResourceFieldValueValidation() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: Validated<String>?
    feature
      .fieldValuePublisher("name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssert(!(result?.isValid ?? false))

    feature
      .setFieldValue("updated", "name")
      .sinkDrop()
      .store(in: cancellables)

    XCTAssert(result?.isValid ?? false)
  }

  func test_setFieldValue_fails_whenResourceFieldNotAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: TheError?
    feature
      .setFieldValue("updated", "unavailable")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidOrMissingResourceType)
  }

  func test_setFieldValue_succeeds_whenResourceFieldAvailable() {
    database.fetchResourcesTypesOperation.execute = always(Just([defaultResourceType]).setFailureType(to: TheError.self).eraseToAnyPublisher())
    features.use(database)
    features.use(networkClient)

    let feature: ResourceCreateForm = testInstance()

    var result: Void?
    feature
      .setFieldValue("updated", "name")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: {
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }
}

private let emptyResourceType: ResourceType = .init(
  id: "empty",
  slug: "empty",
  name: "empty",
  fields: []
)

private let defaultResourceType: ResourceType = .init(
  id: "password-and-description",
  slug: "password-and-description",
  name: "password-and-description",
  fields: [
    .string(name: "name", required: true, encrypted: false, maxLength: nil),
    .string(name: "uri", required: false, encrypted: false, maxLength: nil),
    .string(name: "username", required: false, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "description", required: false, encrypted: true, maxLength: nil),
  ]
)
