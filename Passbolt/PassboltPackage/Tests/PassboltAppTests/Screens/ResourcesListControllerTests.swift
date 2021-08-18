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

import Accounts
import Combine
import Features
import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceListControllerTests: TestCase {

  var resources: Resources!

  override func setUp() {
    super.setUp()

    resources = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    resources = nil
  }

  func test_refreshResources_succeeds_whenResourcesRefreshSuceeds() {
    resources.refreshIfNeeded = always(
      Empty<Never, TheError>(completeImmediately: true)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result: Void?
    controller
      .refreshResources()
      .sink { completion in
        guard case .finished = completion
        else { return }
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_refreshResources_fails_whenResourcesRefreshFails() {
    resources.refreshIfNeeded = always(
      Fail<Never, TheError>(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result: TheError?
    controller
      .refreshResources()
      .sink { completion in
        guard case let .failure(error) = completion
        else { return }
        result = error
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_resourcesListPublisher_publishesResourcesListFromResources() {
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        permission: .read,
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        permission: .read,
        name: "Resoure 2",
        url: "passbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result: Array<ResourcesListViewResourceItem>?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result, resourcesList.map(ResourcesListViewResourceItem.init(from:)))
  }

  func test_resourcesListPublisher_requestsResourcesListWithFilters() {
    var result: ResourcesFilter?
    resources.filteredResourcesListPublisher = { filterPublisher in
      filterPublisher.map { filter in
        result = filter
        return []
      }
      .eraseToAnyPublisher()
    }
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter(text: "1"))

    let controller: ResourcesListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    controller
      .resourcesListPublisher()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, ResourcesFilter(text: "1"))
  }

  func test_resourceDetailsPresentationPublisher_publishesResourceID() {
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        permission: .read,
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        permission: .read,
        name: "Resoure 2",
        url: "passbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result: Resource.ID!

    controller
      .resourceDetailsPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentResourceDetails(resourcesList.first.map(ResourcesListViewResourceItem.init(from:))!)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.rawValue, resourcesList.first!.id.rawValue)
  }
}
