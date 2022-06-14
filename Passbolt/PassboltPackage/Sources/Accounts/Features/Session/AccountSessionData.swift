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
import NetworkClient

import struct Foundation.Date

public struct AccountSessionData {

  public var refreshIfNeeded: () async throws -> Void
  public var updatesSequence: () -> AnyAsyncSequence<Void>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension AccountSessionData: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let featureConfig: FeatureConfig = try await features.instance()

    let foldersEnabled: Bool
    switch await featureConfig.configuration(for: FeatureFlags.Folders.self) {
    case .disabled:
      foldersEnabled = false

    case .enabled:
      foldersEnabled = true
    }

    let updates: AsyncVariable = .init(initial: Void())

    let refreshTask: ManagedTask<Void> = .init()

    nonisolated func refreshUsers() async throws {
      diagnostics.diagnosticLog("Refreshing users data...")
      do {
        try await accountDatabase
          .storeUsers(
            networkClient
              .userListRequest
              .makeAsync(using: .init(resourceIDFilter: .none))
              .body
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

    nonisolated func refreshUserGroups() async throws {
      diagnostics.diagnosticLog("Refreshing user groups data...")
      do {
        try await accountDatabase
          .storeUserGroups(
            networkClient
              .userGroupsRequest
              .makeAsync()
              .body
          )

        diagnostics.diagnosticLog("...user groups data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...user groups data refresh failed!")
        throw error
      }
    }

    nonisolated func refreshFolders() async throws {
      guard foldersEnabled
      else {
        return diagnostics.diagnosticLog("Refreshing folders skipped, feature disabled!")
      }
      diagnostics.diagnosticLog("Refreshing folders data...")
      do {
        try await accountDatabase
          .storeFolders(
            networkClient
              .foldersRequest
              .makeAsync()
              .body
          )

        diagnostics.diagnosticLog("...folders data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...folders data refresh failed!")
        throw error
      }
    }

    nonisolated func refreshResources() async throws {
      diagnostics.diagnosticLog("Refreshing resources data...")
      do {
        try await accountDatabase
          .storeResourcesTypes(
            networkClient
              .resourcesTypesRequest
              .makeAsync()
              .body
          )

        try await accountDatabase
          .storeResources(
            networkClient
              .resourcesRequest
              .makeAsync()
              .body
          )

        diagnostics.diagnosticLog("...resources data refresh finished!")
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("...resources data refresh failed!")
        throw error
      }
    }

    nonisolated func refreshIfNeeded() async throws {
      try await refreshTask.run {
        // TODO: when diffing endpoint becomes available
        // there should be some additional logic here
        // to selectively update database data

        try await refreshUsers()
        try await refreshUserGroups()
        try await refreshFolders()
        try await refreshResources()

        await updates.send(Void())
      }
    }

    nonisolated func updatesSequence() -> AnyAsyncSequence<Void> {
      updates.asAnyAsyncSequence()
    }

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      refreshIfNeeded: refreshIfNeeded,
      updatesSequence: updatesSequence,
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension AccountSessionData {

  public static var placeholder: Self {
    Self(
      refreshIfNeeded: unimplemented("You have to provide mocks for used methods"),
      updatesSequence: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
