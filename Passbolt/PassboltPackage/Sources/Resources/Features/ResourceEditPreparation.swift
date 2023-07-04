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

public struct ResourceEditPreparation {

  public var prepareNew:
    @Sendable (
      _ slug: ResourceSpecification.Slug,
      _ parentFolderID: ResourceFolder.ID?,
      _ uri: URLString?
    ) async throws -> ResourceEditingContext

  public var prepareExisting: @Sendable (Resource.ID) async throws -> ResourceEditingContext

  public var availableTypes: @Sendable () async throws -> Array<ResourceType>

  public init(
    prepareNew: @escaping @Sendable (
      _ slug: ResourceSpecification.Slug,
      _ parentFolderID: ResourceFolder.ID?,
      _ uri: URLString?
    ) async throws -> ResourceEditingContext,
    prepareExisting: @escaping @Sendable (Resource.ID) async throws -> ResourceEditingContext,
    availableTypes: @escaping @Sendable () async throws -> Array<ResourceType>
  ) {
    self.prepareNew = prepareNew
    self.prepareExisting = prepareExisting
    self.availableTypes = availableTypes
  }
}

extension ResourceEditPreparation: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      prepareNew: unimplemented3(),
      prepareExisting: unimplemented1(),
      availableTypes: unimplemented0()
    )
  }
  #endif
}

public struct ResourceEditingContext {

  public var editedResource: Resource
  public var availableTypes: Array<ResourceType>

  public init(
    editedResource: Resource,
    availableTypes: Array<ResourceType>
  ) {
    assert(
      editedResource.secretAvailable,
      "Can't edit a resource without the secret!"
    )
    self.editedResource = editedResource
    self.availableTypes = availableTypes
  }
}
