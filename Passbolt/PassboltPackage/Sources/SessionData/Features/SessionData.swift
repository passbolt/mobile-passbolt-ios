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

import Commons
import Features

public struct SessionData: Sendable {

  public var lastUpdate: AnyUpdatable<Timestamp>
  /// Determinate refresh state and progress in one stream: `nil` while idle, `.some(fraction)` in
  /// the `0.0 ... 1.0` range while a refresh runs. Emits `.some(0)` when a refresh starts, advances
  /// through equal-weight step milestones (and page-by-page during paginated steps), reaches
  /// `.some(1)` on success, then `nil` once finished. A single ordered stream means "is refreshing"
  /// (`value != nil`) and the reported progress never race against each other.
  public var refreshProgress: AnyUpdatable<Double?>
  public var refreshIfNeeded: @Sendable () async throws -> Void
  /// Refreshes only the users and user groups, for screens that pick permission recipients and would otherwise
  /// pay for a full session refresh (metadata, folders and every resource) to see a newly invited user.
  public var refreshUsersAndGroups: @Sendable () async throws -> Void
  public var updateResource: @Sendable (ResourceDTO) async throws -> Void

  public init(
    lastUpdate: AnyUpdatable<Timestamp>,
    refreshProgress: AnyUpdatable<Double?>,
    refreshIfNeeded: @escaping @Sendable () async throws -> Void,
    refreshUsersAndGroups: @escaping @Sendable () async throws -> Void,
    updateResource: @escaping @Sendable (ResourceDTO) async throws -> Void
  ) {
    self.lastUpdate = lastUpdate
    self.refreshProgress = refreshProgress
    self.refreshIfNeeded = refreshIfNeeded
    self.refreshUsersAndGroups = refreshUsersAndGroups
    self.updateResource = updateResource
  }
}

extension SessionData: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    .init(
      lastUpdate: PlaceholderUpdatable().asAnyUpdatable(),
      refreshProgress: PlaceholderUpdatable().asAnyUpdatable(),
      refreshIfNeeded: unimplemented0(),
      refreshUsersAndGroups: unimplemented0(),
      updateResource: unimplemented1()
    )
  }
  #endif
}
