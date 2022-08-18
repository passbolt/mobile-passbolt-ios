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
import SessionData

extension SessionData {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: Diagnostics = try await features.instance()
    let sessionConfiguration: SessionConfiguration = try await features.instance()
    let usersStoreDatabaseOperation: UsersStoreDatabaseOperation = try await features.instance()
    let userGroupsStoreDatabaseOperation: UserGroupsStoreDatabaseOperation = try await features.instance()
    let resourcesStoreDatabaseOperation: ResourcesStoreDatabaseOperation = try await features.instance()
    let resourceTypesStoreDatabaseOperation: ResourceTypesStoreDatabaseOperation = try await features.instance()
    let resourceFoldersStoreDatabaseOperation: ResourceFoldersStoreDatabaseOperation = try await features.instance()
    let usersFetchNetworkOperation: UsersFetchNetworkOperation = try await features.instance()
    let userGroupsFetchNetworkOperation: UserGroupsFetchNetworkOperation = try await features.instance()
    let resourcesFetchNetworkOperation: ResourcesFetchNetworkOperation = try await features.instance()
    let resourceTypesFetchNetworkOperation: ResourceTypesFetchNetworkOperation = try await features.instance()
    let resourceFoldersFetchNetworkOperation: ResourceFoldersFetchNetworkOperation = try await features.instance()

    let foldersEnabled: Bool
    switch await sessionConfiguration.configuration(for: FeatureFlags.Folders.self) {
    case .disabled:
      foldersEnabled = false

    case .enabled:
      foldersEnabled = true
    }

    let updatesSequenceSource: UpdatesSequenceSource = .init()

    let refreshTask: ManagedTask<Void> = .init()

    @Sendable nonisolated func refreshUsers() async throws {
      diagnostics.diagnosticLog("Refreshing users data...")
      do {
        try await usersStoreDatabaseOperation(
          usersFetchNetworkOperation()
            .filter(\.isValid)
            .compactMap(\.asFilteredDSO)
        )
        diagnostics.diagnosticLog("...users data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...users data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshUserGroups() async throws {
      diagnostics.diagnosticLog("Refreshing user groups data...")
      do {
        try await userGroupsStoreDatabaseOperation(
          userGroupsFetchNetworkOperation()
            .filter(\.isValid)
        )

        diagnostics.diagnosticLog("...user groups data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...user groups data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshFolders() async throws {
      guard foldersEnabled
      else {
        return diagnostics.diagnosticLog("Refreshing folders skipped, feature disabled!")
      }
      diagnostics.diagnosticLog("Refreshing folders data...")
      do {
        try await resourceFoldersStoreDatabaseOperation(
          resourceFoldersFetchNetworkOperation()
            .filter(\.isValid)
        )

        diagnostics.diagnosticLog("...folders data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...folders data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func refreshResources() async throws {
      diagnostics.diagnosticLog("Refreshing resources data...")
      do {
        try await resourceTypesStoreDatabaseOperation(
          resourceTypesFetchNetworkOperation()
        )

        try await resourcesStoreDatabaseOperation(
          resourcesFetchNetworkOperation()
            .filter(\.isValid)
        )

        diagnostics.diagnosticLog("...resources data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...resources data refresh failed!")
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

    return Self(
      updatesSequence: updatesSequenceSource.updatesSequence,
      refreshIfNeeded: refreshIfNeeded
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionData() {
    self.use(
      .lazyLoaded(
        SessionData.self,
        load: SessionData.load(features:cancellables:)
      )
    )
  }
}
