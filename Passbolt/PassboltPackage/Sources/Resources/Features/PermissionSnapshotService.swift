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

/// Builds the immutable ``PermissionSnapshot`` shown on the permission confirmation screen and, on confirmation,
/// compares a freshly built snapshot against the confirmed one to detect drift.
///
/// The snapshot is built in two steps from the server (never the local database, which is only a point-in-time
/// cache): first the current permissions of the resource or folder are fetched, then every referenced user and
/// group is expanded by id to gather membership, public keys and fingerprints.
///
/// The create flow additionally runs the existing share dry-run (`ResourceSimulateShareNetworkOperation`) and
/// feeds its newly-added recipients into ``unexpectedRecipients(_:_:)`` - a recipient the operator never saw is
/// treated as drift.
public struct PermissionSnapshotService: Sendable {

  /// Builds a snapshot from a resource's current server permissions.
  public var forResource: @Sendable (Resource.ID) async throws -> PermissionSnapshot
  /// Builds a snapshot from a folder's current server permissions.
  public var forFolder: @Sendable (ResourceFolder.ID) async throws -> PermissionSnapshot
  /// Adds operator-picked recipients to a snapshot: fetches their keys/membership and merges them into
  /// `users`/`groups`. `permissions` (the drift baseline) is left untouched.
  public var expanding:
    @Sendable (_ snapshot: PermissionSnapshot, _ addedUserIDs: Array<User.ID>, _ addedGroupIDs: Array<UserGroup.ID>)
      async throws -> PermissionSnapshot
  /// Compares the current snapshot against the confirmed one across permissions, fingerprints and memberships.
  public var drift: @Sendable (_ confirmed: PermissionSnapshot, _ current: PermissionSnapshot) -> PermissionDrift
  /// Recipients reported by the create-flow dry-run that were not part of the confirmed snapshot.
  public var unexpectedRecipients:
    @Sendable (_ confirmed: PermissionSnapshot, _ simulatedAdded: Array<User.ID>) ->
      OrderedSet<User.ID>

  public init(
    forResource: @escaping @Sendable (Resource.ID) async throws -> PermissionSnapshot,
    forFolder: @escaping @Sendable (ResourceFolder.ID) async throws -> PermissionSnapshot,
    expanding: @escaping @Sendable (PermissionSnapshot, Array<User.ID>, Array<UserGroup.ID>) async throws ->
      PermissionSnapshot,
    drift: @escaping @Sendable (PermissionSnapshot, PermissionSnapshot) -> PermissionDrift,
    unexpectedRecipients: @escaping @Sendable (PermissionSnapshot, Array<User.ID>) -> OrderedSet<User.ID>
  ) {
    self.forResource = forResource
    self.forFolder = forFolder
    self.expanding = expanding
    self.drift = drift
    self.unexpectedRecipients = unexpectedRecipients
  }
}

extension PermissionSnapshotService: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    .init(
      forResource: unimplemented1(),
      forFolder: unimplemented1(),
      expanding: unimplemented3(),
      drift: unimplemented2(),
      unexpectedRecipients: unimplemented2()
    )
  }
  #endif
}
