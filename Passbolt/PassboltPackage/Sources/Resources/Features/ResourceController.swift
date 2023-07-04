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

public struct ResourceController {

  public var state: any DataSource<Resource>
  public var fetchSecretIfNeeded: @Sendable (Bool) async throws -> JSON
  public var loadUserPermissionsDetails: @Sendable () async throws -> Array<UserPermissionDetailsDSV>
  public var loadUserGroupPermissionsDetails: @Sendable () async throws -> Array<UserGroupPermissionDetailsDSV>
  public var toggleFavorite: @Sendable () async throws -> Void
  public var delete: @Sendable () async throws -> Void

  public init(
    state: any DataSource<Resource>,
    fetchSecretIfNeeded: @escaping @Sendable (Bool) async throws -> JSON,
    loadUserPermissionsDetails: @escaping @Sendable () async throws -> Array<UserPermissionDetailsDSV>,
    loadUserGroupPermissionsDetails: @escaping @Sendable () async throws -> Array<UserGroupPermissionDetailsDSV>,
    toggleFavorite: @escaping @Sendable () async throws -> Void,
    delete: @escaping @Sendable () async throws -> Void
  ) {
    self.state = state
    self.fetchSecretIfNeeded = fetchSecretIfNeeded
    self.loadUserPermissionsDetails = loadUserPermissionsDetails
    self.loadUserGroupPermissionsDetails = loadUserGroupPermissionsDetails
    self.toggleFavorite = toggleFavorite
    self.delete = delete
  }
}

extension ResourceController: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG

  public static var placeholder: Self {
    .init(
      state: PlaceholderDataSource(),
      fetchSecretIfNeeded: unimplemented1(),
      loadUserPermissionsDetails: unimplemented0(),
      loadUserGroupPermissionsDetails: unimplemented0(),
      toggleFavorite: unimplemented0(),
      delete: unimplemented0()
    )
  }
  #endif
}

extension ResourceController {

  @discardableResult
  @Sendable public func fetchSecretIfNeeded(
    force: Bool = false
  ) async throws -> JSON {
    try await self.fetchSecretIfNeeded(force)
  }

  @Sendable public func firstTOTPSecret() async throws -> TOTPSecret? {
    return try await self.state.current.firstTOTPSecret
  }
}
