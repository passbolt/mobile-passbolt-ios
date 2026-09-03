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

public struct ResourceShareConfirmation: Sendable {

  /// Grants the confirmed recipients access to a resource `createResourcePrivate` just made. On drift it is left
  /// private and can be shared again. The operator's bootstrap owner permission is settled last, to match what the
  /// folder grants them.
  public var applyToCreatedResource:
    @Sendable (
      _ resourceID: Resource.ID,
      _ folderID: ResourceFolder.ID,
      _ confirmed: OrderedSet<ResourcePermission>,
      _ snapshot: PermissionSnapshot
    ) async throws -> Void

  /// Applies the confirmed set to an existing resource. The secret is not rotated, so revocations and grants go
  /// out atomically; the operator's own change follows separately, since a self-revocation would invalidate it.
  public var applyToSharedResource:
    @Sendable (
      _ resourceID: Resource.ID,
      _ confirmed: OrderedSet<ResourcePermission>,
      _ snapshot: PermissionSnapshot
    ) async throws -> Void

  public init(
    applyToCreatedResource: @escaping @Sendable (
      Resource.ID,
      ResourceFolder.ID,
      OrderedSet<ResourcePermission>,
      PermissionSnapshot
    ) async throws -> Void,
    applyToSharedResource: @escaping @Sendable (
      Resource.ID,
      OrderedSet<ResourcePermission>,
      PermissionSnapshot
    ) async throws -> Void
  ) {
    self.applyToCreatedResource = applyToCreatedResource
    self.applyToSharedResource = applyToSharedResource
  }
}

extension ResourceShareConfirmation: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    .init(
      applyToCreatedResource: unimplemented4(),
      applyToSharedResource: unimplemented3()
    )
  }
  #endif
}
