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

public struct ResourceFolderEditForm {

  public var formState: UpdatableValue<ResourceFolderEditFormState>
  public var setFolderName: @Sendable (String) -> Void
  public var sendForm: @Sendable () async throws -> Void

  public init(
    formState: UpdatableValue<ResourceFolderEditFormState>,
    setFolderName: @escaping @Sendable (String) -> Void,
    sendForm: @escaping @Sendable () async throws -> Void
  ) {
    self.formState = formState
    self.setFolderName = setFolderName
    self.sendForm = sendForm
  }
}

public struct ResourceFolderEditFormState {

  public var name: Validated<String>
  public var location: Validated<Array<ResourceFolderLocationItem>>
  public var permissions: Validated<OrderedSet<ResourceFolderPermissionDSV>>

  public init(
    name: Validated<String>,
    location: Validated<Array<ResourceFolderLocationItem>>,
    permissions: Validated<OrderedSet<ResourceFolderPermissionDSV>>
  ) {
    self.name = name
    self.location = location
    self.permissions = permissions
  }

  public var isValid: Bool {
    self.name.isValid
      && self.permissions.isValid
      && self.location.isValid
  }
}

extension ResourceFolderEditForm: LoadableFeature {

  public enum Context: LoadableFeatureContext, Hashable {

    case create(containingFolderID: ResourceFolder.ID?)
    case modify(folderID: ResourceFolder.ID)
  }

  #if DEBUG

  public static var placeholder: Self {
    Self(
      formState: .placeholder,
      setFolderName: unimplemented(),
      sendForm: unimplemented()
    )
  }
  #endif
}
