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
@MainActor
final class ResourcesSelectionListControllerTests: MainActorTestCase {

  var resources: Resources!
  var autofillContext: AutofillExtensionContext!

  override func mainActorSetUp() {
    resources = .placeholder
    autofillContext = .placeholder
  }

  override func mainActorTearDown() {
    resources = nil
    autofillContext = nil
  }

  func test_refreshResources_succeeds_whenResourcesRefreshSuceeds() async throws {
    await features.use(autofillContext)
    resources.refreshIfNeeded = always(
      Just(Void())
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    let result: Void? =
      try? await controller
      .refreshResources()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshResources_fails_whenResourcesRefreshFails() async throws {
    await features.use(autofillContext)
    resources.refreshIfNeeded = always(
      Fail<Void, Error>(error: MockIssue.error())
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result: Error?
    do {
      try await controller
        .refreshResources()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_resourcesListPublisher_publishesResourcesListFromResources() async throws {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just(Array<AutofillExtensionContext.ServiceIdentifier>())
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "passbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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

  func test_resourcesListPublisher_requestsResourcesListWithFilters() async throws {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just(Array<AutofillExtensionContext.ServiceIdentifier>())
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    var result: ResourcesFilter?
    resources.filteredResourcesListPublisher = { filterPublisher in
      filterPublisher.map { filter in
        result = filter
        return []
      }
      .eraseToAnyPublisher()
    }
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically, text: "1")
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    controller
      .resourcesListPublisher()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, ResourcesFilter(sorting: .nameAlphabetically, text: "1"))
  }

  func test_resourcesListPublisher_publishesSuggestedResourcesListFromResources_usingRequestedServiceIdentifiers()
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alterpassbolt.com")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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

  func test_resourcesListPublisher_publishesOneMatchingResourcesListFromResources_usingRequestedServiceIdentifiers()
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alter.passbolt.com")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alter.passbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com/some/path/here")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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
    async throws
  {
    autofillContext.requestedServiceIdentifiersPublisher = always(
      Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
        .eraseToAnyPublisher()
    )
    await features.use(autofillContext)
    let resourcesList: Array<ListViewResource> = [
      ListViewResource(
        id: "resource_1",
        name: "Resoure 1",
        url: "passbolt.com/some/path/here",
        username: "test"
      ),
      ListViewResource(
        id: "resource_2",
        name: "Resoure 2",
        url: "alterpassbolt.com",
        username: "test"
      ),
    ]
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

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
