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
import CommonModels
import Features
import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceListControllerTests: MainActorTestCase {

  var resources: Resources!

  override func mainActorSetUp() {
    resources = .placeholder
  }

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    features.usePlaceholder(for: AccountSessionData.self)
  }

  override func mainActorTearDown() {
    resources = nil
  }

  func test_refreshResources_succeeds_whenResourcesRefreshSuceeds() async throws {
    await features.patch(
      \AccountSessionData.refreshIfNeeded,
      with: always(Void())
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    let result: Void? =
      try? await controller
      .refreshResources()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshResources_fails_whenResourcesRefreshFails() async throws {
    await features.patch(
      \AccountSessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

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
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    var result: Array<ResourcesResourceListItemDSVItem>?

    controller
      .resourcesListPublisher()
      .sink { values in
        result = values
      }
      .store(in: cancellables)

    XCTAssertEqual(result, resourcesList.map(ResourcesResourceListItemDSVItem.init(from:)))
  }

  func test_resourcesListPublisher_requestsResourcesListWithFilters() async throws {
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

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    controller
      .resourcesListPublisher()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, ResourcesFilter(sorting: .nameAlphabetically, text: "1"))
  }

  func test_resourceDetailsPresentationPublisher_publishesResourceID() async throws {
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
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    var result: Resource.ID!

    controller
      .resourceDetailsPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentResourceDetails(resourcesList.first.map(ResourcesResourceListItemDSVItem.init(from:))!)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.rawValue, resourcesList.first!.id.rawValue)
  }

  func test_resourceMenuPresentationPublisher_publishesResourceID() async throws {
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
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    var result: Resource.ID!

    controller
      .resourceMenuPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentResourceMenu(resourcesList.first.map(ResourcesResourceListItemDSVItem.init(from:))!)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.rawValue, resourcesList.first!.id.rawValue)
  }

  func test_resourceDeleteAlertPresentationPublisher_publishesResourceID_whenPresentDeleteResourceAlertCalled()
    async throws
  {
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
    resources.filteredResourcesListPublisher = always(
      Just(resourcesList)
        .eraseToAnyPublisher()
    )
    await features.use(resources)

    let filtersSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(
      ResourcesFilter(sorting: .nameAlphabetically)
    )

    let controller: ResourcesListController = try await testController(context: filtersSubject.eraseToAnyPublisher())

    var result: Resource.ID!

    controller
      .resourceDeleteAlertPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentDeleteResourceAlert(resourcesList.first!.id)

    XCTAssertNotNil(result)
    XCTAssertEqual(result.rawValue, resourcesList.first!.id.rawValue)
  }
}
