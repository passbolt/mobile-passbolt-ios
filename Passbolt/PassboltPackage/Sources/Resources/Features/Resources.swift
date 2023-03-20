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

import CommonModels
import Features

// MARK: - Interface

public struct Resources {

  public var filteredResourcesListPublisher:
    (AnyPublisher<ResourcesFilter, Never>) -> AnyPublisher<Array<ResourceListItemDSV>, Never>
  public var filteredResourcesList: @Sendable (ResourcesFilter) async throws -> Array<ResourceListItemDSV>
  public var loadResourceSecret: @Sendable (Resource.ID) -> AnyPublisher<ResourceSecret, Error>
  public var resourceDetailsPublisher: (Resource.ID) -> AnyPublisher<Resource, Error>
  @available(*, deprecated, message: "Please switch to async `delete`")
  public var deleteResource: @Sendable (Resource.ID) -> AnyPublisher<Void, Error>
  public var delete: @Sendable (Resource.ID) async throws -> Void

  public init(
    filteredResourcesListPublisher:
      @escaping (AnyPublisher<ResourcesFilter, Never>) -> AnyPublisher<Array<ResourceListItemDSV>, Never>,
    filteredResourcesList:
      @escaping @Sendable (ResourcesFilter) async throws -> Array<ResourceListItemDSV>,
    loadResourceSecret: @escaping @Sendable (Resource.ID) -> AnyPublisher<ResourceSecret, Error>,
    resourceDetailsPublisher: @escaping @Sendable (Resource.ID) -> AnyPublisher<Resource, Error>,
    deleteResource: @escaping @Sendable (Resource.ID) -> AnyPublisher<Void, Error>,
    delete: @escaping @Sendable (Resource.ID) async throws -> Void
  ) {
    self.filteredResourcesListPublisher = filteredResourcesListPublisher
    self.filteredResourcesList = filteredResourcesList
    self.loadResourceSecret = loadResourceSecret
    self.resourceDetailsPublisher = resourceDetailsPublisher
    self.deleteResource = deleteResource
    self.delete = delete
  }
}

extension Resources: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Resources {
    Self(
      filteredResourcesListPublisher: unimplemented1(),
      filteredResourcesList: unimplemented1(),
      loadResourceSecret: unimplemented1(),
      resourceDetailsPublisher: unimplemented1(),
      deleteResource: unimplemented1(),
      delete: unimplemented1()
    )
  }
  #endif
}
