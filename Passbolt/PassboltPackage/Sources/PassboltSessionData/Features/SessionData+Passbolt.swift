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
import Metadata
import NetworkOperations
import OSFeatures
import Resources
import Session
import SessionData

import struct Foundation.Data

extension SessionData {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let configuration: SessionConfiguration = try features.sessionConfiguration()

    let time: OSTime = features.instance()
    let session: Session = try features.instance()

    let usersStoreDatabaseOperation: UsersStoreDatabaseOperation = try features.instance()
    let userGroupsStoreDatabaseOperation: UserGroupsStoreDatabaseOperation = try features.instance()
    let resourceFoldersStoreDatabaseOperation: ResourceFoldersStoreDatabaseOperation = try features.instance()
    let usersFetchNetworkOperation: UsersFetchNetworkOperation = try features.instance()
    let userGroupsFetchNetworkOperation: UserGroupsFetchNetworkOperation = try features.instance()
    let resourceFoldersFetchNetworkOperation: ResourceFoldersFetchNetworkOperation = try features.instance()
    let metadataKeysService: MetadataKeysService = try features.instance()
    let metadataSettings: MetadataSettingsService = try features.instance()
    let resourceUpdater: ResourceUpdater = try features.instance()

    // when diffing endpoint becomes available
    // we could store last update time and reuse it to avoid
    // fetching all the data when initializing
    let lastUpdate: Variable<Timestamp> = .init(initial: 0)
    // `nil` = idle, `.some(fraction)` = refreshing at that progress. One stream carries both the
    // "is refreshing" flag and the determinate progress (see `SessionData.refreshProgress`).
    let refreshProgress: Variable<Double?> = .init(initial: .none)

    let refreshTask: CriticalState<Task<Void, Error>?> = .init(.none)

    Task {  // initial refresh after loading
      do {
        try await refreshIfNeeded()
      }
      catch {
        error.logged()
      }
    }

    /// Publishes a refresh step's progress. `fraction` is how far the step itself has advanced
    /// (`1` = done; paginated steps pass `pagesDone / totalPages`).
    ///
    /// Forward-only and applied only while a refresh is active (`refreshProgress != nil`), so each
    /// stage — including the concurrently-run `prepareMetadata` — can report independently without
    /// moving the bar backwards or resurrecting it after the run finished.
    @Sendable nonisolated func reportRefreshProgress(_ step: RefreshStep, fraction: Double = 1) {
      let target: Double = step.fraction(fraction)
      refreshProgress.mutate { (value: inout Double?) in
        guard let current: Double = value
        else { return }  // idle — ignore late reports
        value = max(current, target)
      }
    }

    // Fetch and store are split so `refreshIfNeeded` can run the (independent) network fetches
    // concurrently while keeping the stores in FK order (users → groups → folders → resources).

    @Sendable nonisolated func refreshUsers(_ fetchedUsers: Array<UserDTO>) async throws {
      Diagnostics.logger.info("Storing users data...")
      do {
        try await usersStoreDatabaseOperation(fetchedUsers.compactMap(\.asFilteredDSO))
        Diagnostics.logger.info("...users data store finished!")
      }
      catch {
        Diagnostics.logger.info("...users data store failed!")
        throw error
      }
      reportRefreshProgress(.users)
    }

    @Sendable nonisolated func refreshUserGroups(_ fetchedUserGroups: Array<UserGroupDTO>) async throws {
      Diagnostics.logger.info("Storing user groups data...")
      do {
        try await userGroupsStoreDatabaseOperation(fetchedUserGroups)
        Diagnostics.logger.info("...user groups data store finished!")
      }
      catch {
        Diagnostics.logger.info("...user groups data store failed!")
        throw error
      }
      reportRefreshProgress(.userGroups)
    }

    /// Fetches folders only when the feature is enabled; returns an empty set (and skips the request)
    /// otherwise, so the concurrent fetch is always safe to start.
    @Sendable nonisolated func fetchFolders() async throws -> Array<ResourceFolderDTO> {
      guard configuration.folders.enabled
      else {
        Diagnostics.logger.info("Fetching folders skipped, feature disabled!")
        return []
      }
      return try await resourceFoldersFetchNetworkOperation()
    }

    @Sendable nonisolated func refreshFolders(_ fetchedFolders: Array<ResourceFolderDTO>) async throws {
      // Folders left untouched when disabled — never store an empty set — but the step still reports
      // as completed so a skipped feature-flagged step advances the bar (matching the Android model).
      if configuration.folders.enabled {
        Diagnostics.logger.info("Storing folders data...")
        do {
          try await resourceFoldersStoreDatabaseOperation(fetchedFolders)
          Diagnostics.logger.info("...folders data store finished!")
        }
        catch {
          Diagnostics.logger.info("...folders data store failed!")
          throw error
        }
      }
      // TODO: when the folders endpoint becomes paginated, report `.folders` incrementally with
      // `fraction: pagesDone / totalPages` like `.resources` below.
      reportRefreshProgress(.folders)
    }

    /// Fetches metadata settings and initializes metadata keys. Independent of users/groups/folders, so
    /// it is run concurrently with them; it must complete before resources are decrypted.
    @Sendable nonisolated func prepareMetadata() async throws {
      if configuration.metadata.enabled {
        try await metadataSettings.fetchSettings()
        try await metadataKeysService.initialize()
      }
      // Reports as completed even when disabled; `reportRefreshProgress` is forward-only, so this
      // concurrently-run step can land here in any order without moving the bar backwards.
      reportRefreshProgress(.metadata)
    }

    @Sendable nonisolated func refreshResources() async throws {
      Diagnostics.logger.info("Refreshing resources data...")
      do {
        try await resourceUpdater.updateResources(
          isInApplicationContext ? .application : .extension
        ) { (fraction: Double) in
          // Paginated step: fills its equal-weight segment as pages are processed.
          reportRefreshProgress(.resources, fraction: fraction)
        }
        Diagnostics.logger.info("...resources data refresh finished!")
      }
      catch {
        Diagnostics.logger.info("...resources data refresh failed!")
        throw error
      }
    }

    @Sendable nonisolated func updateResource(_ resource: ResourceDTO) async throws {
      try await session.execute {
        try await resourceUpdater.updateResource(resource)
        lastUpdate.mutate { (lastUpdate: inout Timestamp) in
          lastUpdate = time.timestamp()
        }
      }
      .value
    }

    @Sendable nonisolated func refreshIfNeeded() async throws {
      let task: Task<Void, Error> = refreshTask.access { (task: inout Task<Void, Error>?) -> Task<Void, Error> in
        if let runningTask: Task<Void, Error> = task {
          return runningTask
        }
        else {
          // Enter the active state at 0 progress (this is the only backwards move — a fresh start).
          refreshProgress.assign(.some(0))
          let runningTask: Task<Void, Error> = session.execute {
            defer {
              refreshTask.access { task in
                task = .none
              }
              // Back to idle regardless of how the body terminated (success pins 1.0 just before this).
              refreshProgress.assign(.none)
            }
            // when diffing endpoint becomes available
            // there should be some additional logic
            // to selectively update database data
            //
            // The refresh fetches are independent (no fetch consumes another's response), so start them
            // concurrently — they overlap on the wire — then store in FK order (users → groups → folders
            // → resources). Metadata prep (settings + the RSA key init, the largest non-resource cost) is
            // independent too, so it overlaps the whole store chain; only the brief SessionActor request
            // prep and the DB stores themselves serialize.
            async let fetchedUsers: Array<UserDTO> = usersFetchNetworkOperation()
            async let fetchedUserGroups: Array<UserGroupDTO> = userGroupsFetchNetworkOperation()
            async let fetchedFolders: Array<ResourceFolderDTO> = fetchFolders()
            async let preparedMetadata: Void = prepareMetadata()

            try await refreshUsers(fetchedUsers)
            try await refreshUserGroups(fetchedUserGroups)
            try await refreshFolders(fetchedFolders)
            // Metadata keys must be ready before resources are decrypted.
            try await preparedMetadata
            try await refreshResources()

            if configuration.metadata.enabled {
              try await metadataKeysService.sendSessionKeys()
            }
            // when diffing endpoint becomes available
            // we should use server time instead
            lastUpdate.mutate { (lastUpdate: inout Timestamp) in
              lastUpdate = time.timestamp()
            }
            // Final step; reported even when metadata is disabled (skipped counts as completed), so
            // a successful refresh pins progress to 1.0 before the defer returns it to idle.
            reportRefreshProgress(.sessionKeys)
          }
          // Return to idle on completion regardless of how the task body terminated, in case the
          // body threw before the defer above ran.
          Task { @Sendable in
            _ = try? await runningTask.value
            refreshProgress.assign(.none)
          }
          task = runningTask
          return runningTask
        }
      }

      return try await task.value
    }

    return Self(
      lastUpdate: lastUpdate.asAnyUpdatable(),
      refreshProgress: refreshProgress.asAnyUpdatable(),
      refreshIfNeeded: refreshIfNeeded,
      updateResource: updateResource
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionData() {
    self.use(
      .lazyLoaded(
        SessionData.self,
        load: SessionData.load(features:)
      ),
      in: SessionScope.self
    )
  }
}

extension ResourceUpdater.Configuration {

  fileprivate static let application: Self = .init(
    maximumChunkSize: 5_000,
    maximumConcurrentTasks: 5,
    maximumConcurrentDecryptions: 4
  )

  fileprivate static let `extension`: Self = .init(
    maximumChunkSize: 3_000,
    maximumConcurrentTasks: 5,
    maximumConcurrentDecryptions: 4
  )
}

/// The top-level steps of a full refresh, each owning an equal `1 / allCases.count` slice of the
/// progress bar (the Android model). A step's progress is `(index + stepFraction) / total`, so
/// completing step *k* pins the bar at `(k + 1) / total`; paginated steps fill their own slice
/// gradually via `stepFraction = pagesDone / totalPages`. Feature-flagged steps that don't run
/// still report as completed, so the bar simply jumps forward.
///
/// Order defines the slice each step occupies. iOS decomposes the refresh into fewer requests than
/// Android (e.g. metadata setup is one step here), so the step count differs while the model — equal
/// weight, skipped-counts-as-done, paginated-fill — matches.
// Internal (not private) so the equal-step math can be unit-tested directly.
internal enum RefreshStep: Int, CaseIterable {

  case users
  case userGroups
  case folders  // paginated once the folders endpoint supports it
  case metadata
  case resources  // paginated
  case sessionKeys

  /// Progress fraction (`0...1`) once this step has advanced by `stepFraction`
  /// (`1` = done; paginated steps pass `pagesDone / totalPages`).
  internal func fraction(_ stepFraction: Double) -> Double {
    let clamped: Double = min(max(stepFraction, 0.0), 1.0)
    return (Double(self.rawValue) + clamped) / Double(Self.allCases.count)
  }
}
