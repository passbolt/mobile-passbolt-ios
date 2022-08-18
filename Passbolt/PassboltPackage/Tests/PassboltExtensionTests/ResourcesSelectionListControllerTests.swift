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
import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltExtension

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourcesSelectionListControllerTests: MainActorTestCase {

  var updatesSequence: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features.usePlaceholder(for: AutofillExtensionContext.self)
    features.usePlaceholder(for: Resources.self)
    updatesSequence = .init()
    features.patch(
      \SessionData.updatesSequence,
      with: updatesSequence.updatesSequence
    )
  }

  override func mainActorTearDown() {
    updatesSequence = .none
  }

  func test_refreshResources_succeeds_whenResourcesRefreshSuceeds() async throws {
    features.patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

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
    features.patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

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
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just(Array<AutofillExtensionContext.ServiceIdentifier>())
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "passbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result?.suggested, Array<ResourcesSelectionResourceListItemDSVItem>())
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func test_resourcesListPublisher_requestsResourcesListWithFilters() async throws {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just(Array<AutofillExtensionContext.ServiceIdentifier>())
          .eraseToAnyPublisher()
      )
    )

    var result: ResourcesFilter?
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: { filtersPublisher in
        filtersPublisher.map { filter in
          result = filter
          return []
        }
        .eraseToAnyPublisher()
      }
    )

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
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alterpassbolt.com")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alterpassbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[1]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func test_resourcesListPublisher_publishesOneMatchingResourcesListFromResources_usingRequestedServiceIdentifiers()
    async throws
  {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://alter.passbolt.com")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alterpassbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesOneMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiers()
    async throws
  {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alter.passbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiers()
    async throws
  {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alterpassbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiersWithURLPath()
    async throws
  {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com/some/path/here")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alterpassbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }

  func
    test_resourcesListPublisher_publishesSingleMatchingSuggestionsResourcesListFromResources_usingRequestedServiceIdentifiersWithResourceURLPath()
    async throws
  {
    features.patch(
      \AutofillExtensionContext.requestedServiceIdentifiersPublisher,
      with: always(
        Just([AutofillExtensionContext.ServiceIdentifier(rawValue: "https://passbolt.com")])
          .eraseToAnyPublisher()
      )
    )
    let resourcesList: Array<ResourceListItemDSV> = [
      ResourceListItemDSV(
        id: "resource_1",
        parentFolderID: .none,
        name: "Resoure 1",
        username: "test",
        url: "passbolt.com/some/path/here"
      ),
      ResourceListItemDSV(
        id: "resource_2",
        parentFolderID: .none,
        name: "Resoure 2",
        username: "test",
        url: "alterpassbolt.com"
      ),
    ]
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just(resourcesList)
          .eraseToAnyPublisher()
      )
    )

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesSelectionListController = try await testController(
      context: filtersSubject.eraseToAnyPublisher()
    )

    var result:
      (
        suggested: Array<ResourcesSelectionResourceListItemDSVItem>,
        all: Array<ResourcesSelectionResourceListItemDSVItem>
      )?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(
      result?.suggested,
      [ResourcesSelectionResourceListItemDSVItem(from: resourcesList[0]).suggestionCopy]
    )
    XCTAssertEqual(result?.all, resourcesList.map(ResourcesSelectionResourceListItemDSVItem.init(from:)))
  }
}
