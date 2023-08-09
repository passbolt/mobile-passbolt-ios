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
import FeatureScopes
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

    let time: OSTime = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

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

    // when diffing endpoint becomes available
    // we could store last update time and reuse it to avoid
    // fetching all the data when initializing
    let lastUpdate: Variable<Timestamp> = .init(initial: 0)

    let refreshTask: CriticalState<Task<Void, Error>?> = .init(.none)

    // initial refresh after loading
    asyncExecutor.schedule {
      do {
        try await refreshIfNeeded()
      }
      catch {
        error.logged()
      }
    }

    @Sendable nonisolated func refreshUsers() async throws {
      Diagnostics.logger.info("Refreshing users data...")
      do {
        try await usersStoreDatabaseOperation(
          usersFetchNetworkOperation()
            .compactMap(\.asFilteredDSO)
        )
        Diagnostics.logger.info("...users data refresh finished!")
      }
      catch {
				Diagnostics.logger.info("...users data refresh failed!")
				throw error
      }
    }

    @Sendable nonisolated func refreshUserGroups() async throws {
      Diagnostics.logger.info("Refreshing user groups data...")
      do {
        try await userGroupsStoreDatabaseOperation(
          userGroupsFetchNetworkOperation()
        )

        Diagnostics.logger.info("...user groups data refresh finished!")
      }
      catch {
				Diagnostics.logger.info("...user groups data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshFolders() async throws {
      guard configuration.foldersEnabled
      else {
        return Diagnostics.logger.info("Refreshing folders skipped, feature disabled!")
      }
      Diagnostics.logger.info("Refreshing folders data...")
      do {
        try await resourceFoldersStoreDatabaseOperation(
          resourceFoldersFetchNetworkOperation()
        )

        Diagnostics.logger.info("...folders data refresh finished!")
      }
      catch {
				Diagnostics.logger.info("...folders data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshResources() async throws {
      Diagnostics.logger.info("Refreshing resources data...")
      do {
        try await resourceTypesStoreDatabaseOperation(
          resourceTypesFetchNetworkOperation()
        )

        try await resourcesStoreDatabaseOperation(
          resourcesFetchNetworkOperation()
        )

        Diagnostics.logger.info("...resources data refresh finished!")
      }
      catch {
				Diagnostics.logger.info("...resources data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshIfNeeded() async throws {
      let task: Task<Void, Error> = refreshTask.access { (task: inout Task<Void, Error>?) -> Task<Void, Error> in
        if let runningTask: Task<Void, Error> = task {
          return runningTask
        }
        else {
          let runningTask: Task<Void, Error> = .init {
            defer {
              refreshTask.access { task in
                task = .none
              }
            }
            // when diffing endpoint becomes available
            // there should be some additional logic
            // to selectively update database data

            try await refreshUsers()
            try await refreshUserGroups()
            try await refreshFolders()
            try await refreshResources()

            // when diffing endpoint becomes available
            // we should use server time instead
            lastUpdate.mutate { (lastUpdate: inout Timestamp) in
              lastUpdate = time.timestamp()
            }
          }
          task = runningTask
          return runningTask
        }
      }

      return try await task.value
    }

    return Self(
      lastUpdate: lastUpdate.asAnyUpdatable(),
      refreshIfNeeded: refreshIfNeeded
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
