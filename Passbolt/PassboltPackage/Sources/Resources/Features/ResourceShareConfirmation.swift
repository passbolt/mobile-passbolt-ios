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

/// Applies operator-confirmed permissions to a resource created privately during the create-in-shared-folder flow.
///
/// The resource is created first with the operator as its sole owner (see `ResourceEditForm.createResourcePrivate`).
/// This step then re-checks the folder against the confirmed snapshot for drift and, only if clear, encrypts the
/// secret for the newly-added recipients **using the snapshot's public keys** (recipients fetched just for the
/// operation may not be in the local database yet - Option 1) and saves the permissions in a single share call.
///
/// On drift it throws ``PermissionDriftDetected`` and applies nothing: the resource is left private, owned by the
/// operator, who can share it again.
public struct ResourceShareConfirmation: Sendable {

  /// - Parameter ownPermissionID: identifier of the operator's owner permission created together with the
  ///   resource. The confirmed list decides what the operator keeps, exactly as folder inheritance would.
  public var applyToCreatedResource:
    @Sendable (
      _ resourceID: Resource.ID,
      _ ownPermissionID: Permission.ID,
      _ folderID: ResourceFolder.ID,
      _ confirmed: OrderedSet<ResourcePermission>,
      _ snapshot: PermissionSnapshot
    ) async throws -> Void

  public init(
    applyToCreatedResource: @escaping @Sendable (
      Resource.ID,
      Permission.ID,
      ResourceFolder.ID,
      OrderedSet<ResourcePermission>,
      PermissionSnapshot
    ) async throws -> Void
  ) {
    self.applyToCreatedResource = applyToCreatedResource
  }
}

extension ResourceShareConfirmation: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    .init(
      applyToCreatedResource: unimplemented5()
    )
  }
  #endif
}
