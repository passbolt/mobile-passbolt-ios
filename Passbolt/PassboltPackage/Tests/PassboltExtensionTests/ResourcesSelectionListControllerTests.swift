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

@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourcesSelectionListControllerTests: TestCase {

  var resources: Resources!
  var autofillContext: AutofillExtensionContext!

  override func setUp() {
    super.setUp()

    resources = .placeholder
    autofillContext = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    resources = nil
    autofillContext = nil
  }

  func test_refreshResources_succeeds_whenResourcesRefreshSuceeds() {
    features.use(autofillContext)
    resources.refreshIfNeeded = always(
      Empty<Never, TheError>(completeImmediately: true)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

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
    features.use(autofillContext)
    resources.refreshIfNeeded = always(
      Fail<Never, TheError>(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

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
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just(Array<AutofillExtensionContext.ServiceIdentifier>())
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, Array<ResourcesSelectionListViewResourceItem>())
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func test_resourcesListPublisher_requestsResourcesListWithFilters() {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just(Array<AutofillExtensionContext.ServiceIdentifier>())
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    controller
      .resourcesListPublisher()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, ResourcesFilter(text: "1"))
  }

  func test_resourcesListPublisher_publishesSuggestedResourcesListFromResources_usingRequestedServiceIdentifiers() {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alterpassbolt.com")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, [ResourcesSelectionListViewResourceItem(from: resourcesList[1]).suggestionCopy])
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func test_resourcesListPublisher_publishesOneMatchingResourcesListFromResources_usingRequestedServiceIdentifiers() {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alter.passbolt.com")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionListViewResourceItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesOneMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiers()
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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
        url: "alter.passbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionListViewResourceItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiers()
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, [ResourcesSelectionListViewResourceItem(from: resourcesList[0]).suggestionCopy])
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiersWithURLPath()
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com/some/path/here")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
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
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, [ResourcesSelectionListViewResourceItem(from: resourcesList[0]).suggestionCopy])
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiersWithResourceURLPath()
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        permission: .read,
        name: "Resoure 1",
        url: "passbolt.com/some/path/here",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        permission: .read,
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(ResourcesFilter())

    let controller: ResourcesSelectionListController = testInstance(context: filtersSubject.eraseToAnyPublisher())

    var result:
      (suggested: Array<ResourcesSelectionListViewResourceItem>, all: Array<ResourcesSelectionListViewResourceItem>)?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, [ResourcesSelectionListViewResourceItem(from: resourcesList[0]).suggestionCopy])
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionListViewResourceItem.init(from:)))
  }
}
