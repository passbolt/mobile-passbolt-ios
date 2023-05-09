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

import DatabaseOperations
import Features
import NetworkOperations
import OSFeatures
import SessionData

extension SessionData {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let configuration: SessionConfiguration = try features.sessionConfiguration()

    let diagnostics: OSDiagnostics = features.instance()
    let usersStoreDatabaseOperation: UsersStoreDatabaseOperation = try features.instance()
    let userGroupsStoreDatabaseOperation: UserGroupsStoreDatabaseOperation = try features.instance()
    let resourcesStoreDatabaseOperation: ResourcesStoreDatabaseOperation = try features.instance()
    let resourceTypesStoreDatabaseOperation: ResourceTypesStoreDatabaseOperation = try features.instance()
    let resourceFoldersStoreDatabaseOperation: ResourceFoldersStoreDatabaseOperation = try features.instance()
    let usersFetchNetworkOperation: UsersFetchNetworkOperation = try features.instance()
    let userGroupsFetchNetworkOperation: UserGroupsFetchNetworkOperation = try features.instance()
    let resourcesFetchNetworkOperation: ResourcesFetchNetworkOperation = try features.instance()
    let resourceTypesFetchNetworkOperation: ResourceTypesFetchNetworkOperation = try features.instance()
    let resourceFoldersFetchNetworkOperation: ResourceFoldersFetchNetworkOperation = try features.instance()

    let updatesSequenceSource: UpdatesSequenceSource = .init()

    let refreshTask: ManagedTask<Void> = .init()

    @Sendable nonisolated func refreshUsers() async throws {
      diagnostics.log(diagnostic: "Refreshing users data...")
      do {
        try await usersStoreDatabaseOperation(
          usersFetchNetworkOperation()
            .compactMap(\.asFilteredDSO)
        )
        diagnostics.log(diagnostic: "...users data refresh finished!")
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "...users data refresh failed!"
          )
        )
        throw error
      }
    }

    @Sendable nonisolated func refreshUserGroups() async throws {
      diagnostics.log(diagnostic: "Refreshing user groups data...")
      do {
        try await userGroupsStoreDatabaseOperation(
          userGroupsFetchNetworkOperation()
        )

        diagnostics.log(diagnostic: "...user groups data refresh finished!")
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "...user groups data refresh failed!"
          )
        )
        throw error
      }
    }

    @Sendable nonisolated func refreshFolders() async throws {
      guard configuration.foldersEnabled
      else {
        return diagnostics.log(diagnostic: "Refreshing folders skipped, feature disabled!")
      }
      diagnostics.log(diagnostic: "Refreshing folders data...")
      do {
        try await resourceFoldersStoreDatabaseOperation(
          resourceFoldersFetchNetworkOperation()
        )

        diagnostics.log(diagnostic: "...folders data refresh finished!")
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "...folders data refresh failed!"
          )
        )
        throw error
      }
    }

    @Sendable nonisolated func refreshResources() async throws {
      diagnostics.log(diagnostic: "Refreshing resources data...")
      do {
        try await resourceTypesStoreDatabaseOperation(
          resourceTypesFetchNetworkOperation()
        )

        try await resourcesStoreDatabaseOperation(
          resourcesFetchNetworkOperation()
        )

        diagnostics.log(diagnostic: "...resources data refresh finished!")
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "...resources data refresh failed!"
          )
        )
        throw error
      }
    }

    @Sendable nonisolated func refreshIfNeeded() async throws {
      try await refreshTask.run {
        // TODO: when diffing endpoint becomes available
        // there should be some additional logic
        // to selectively update database data

        try await refreshUsers()
        try await refreshUserGroups()
        try await refreshFolders()
        try await refreshResources()

        updatesSequenceSource.sendUpdate()
      }
    }

    @Sendable func withLocalUpdate(
      _ execute: @escaping @Sendable () async throws -> Void
    ) async throws {
      try await execute()
      updatesSequenceSource.sendUpdate()
    }

    return Self(
      updatesSequence: updatesSequenceSource.updatesSequence,
      refreshIfNeeded: refreshIfNeeded,
      withLocalUpdate: withLocalUpdate(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionData() {
    self.use(
      .lazyLoaded(
        SessionData.self,
        load: SessionData.load(features:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
