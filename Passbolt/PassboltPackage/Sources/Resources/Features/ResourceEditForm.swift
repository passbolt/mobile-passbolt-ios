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

public struct ResourceEditForm {

  // sets currently edited resource, if it was not set default form creates new resource
  // note that editing resource will download and decrypt secrets to fill them in and allow editing
  public var editResource: @Sendable (Resource.ID) -> AnyPublisher<Void, Error>
  // set enclosing folder (parentFolderID)
  public var setEnclosingFolder: @Sendable (ResourceFolder.ID?) -> Void
  // initial version supports only one type of resource type, so there is no method to change it
  public var resourceTypePublisher: () -> AnyPublisher<ResourceTypeDSV, Error>
  // since currently the only field value is String we are not allowing other value types
  public var setFieldValue: @Sendable (String, ResourceFieldName) -> AnyPublisher<Void, Error>
  // prepare publisher for given field, publisher will complete when field will be no longer available
  public var fieldValuePublisher: (ResourceFieldName) -> AnyPublisher<Validated<ResourceFieldValue>, Never>
  // send the form and create resource on server
  public var sendForm: @Sendable () -> AnyPublisher<Resource.ID, Error>

  public init(
    editResource: @escaping @Sendable (Resource.ID) -> AnyPublisher<Void, Error>,
    setEnclosingFolder: @escaping @Sendable (ResourceFolder.ID?) -> Void,
    resourceTypePublisher: @escaping () -> AnyPublisher<ResourceTypeDSV, Error>,
    setFieldValue: @escaping @Sendable (String, ResourceFieldName) -> AnyPublisher<Void, Error>,
    fieldValuePublisher: @escaping (ResourceFieldName) -> AnyPublisher<Validated<ResourceFieldValue>, Never>,
    sendForm: @escaping @Sendable () -> AnyPublisher<Resource.ID, Error>
  ) {
    self.editResource = editResource
    self.setEnclosingFolder = setEnclosingFolder
    self.resourceTypePublisher = resourceTypePublisher
    self.setFieldValue = setFieldValue
    self.fieldValuePublisher = fieldValuePublisher
    self.sendForm = sendForm
  }
}

// TODO: convert to LoadableFeature with
// resource ID (and folder ID?) as a context
extension ResourceEditForm: LoadableContextlessFeature {

  #if DEBUG
  public static var placeholder: ResourceEditForm {
    Self(
      editResource: unimplemented(),
      setEnclosingFolder: unimplemented(),
      resourceTypePublisher: unimplemented(),
      setFieldValue: unimplemented(),
      fieldValuePublisher: unimplemented(),
      sendForm: unimplemented()
    )
  }
  #endif
}
