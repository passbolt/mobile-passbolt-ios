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
import NetworkOperations

import class Foundation.Bundle

public struct UpdateCheck: Sendable {

  public var checkRequired: @MainActor () async -> Bool
  public var updateAvailable: @MainActor () async throws -> Bool
  /// App Store page of the application, available only after a successful update check.
  public var updatePageURL: @MainActor () async -> URLString?
}

extension UpdateCheck: LoadableFeature {

  @MainActor public static func load(
    using features: Features
  ) throws -> Self {
    let updateChecker: UpdateChecker = try .init(
      applicationMeta: features.instance(),
      appVersionsFetchNetworkOperation: features.instance(),
      mdmConfiguration: features.instance()
    )

    return Self(
      checkRequired: updateChecker.isStatusCheckRequired,
      updateAvailable: updateChecker.isUpdateAvailable,
      updatePageURL: updateChecker.updatePageURL
    )
  }

  #if DEBUG
  public static var placeholder: Self {
    Self(
      checkRequired: unimplemented0(),
      updateAvailable: unimplemented0(),
      updatePageURL: unimplemented0()
    )
  }
  #endif
}

extension FeaturesRegistry {

  internal mutating func usePassboltUpdateCheck() {
    self.use(
      // cached - the checker caches its status for the application run, which only
      // holds while the same instance is reused. The splash screen is reached more
      // than once per run and the announcement is meant for the first entry only.
      .lazyLoaded(
        UpdateCheck.self,
        load: { try UpdateCheck.load(using: $0) }
      )
    )
  }
}

public struct ApplicationVersionOutdated: TheError {

  public static func error(
    underlyingError: Error? = .none,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          "ApplicationVersionOutdated",
          file: file,
          line: line
        )
      )
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString = .localized(key: "update.available.message")
}

fileprivate actor UpdateChecker {

  private enum Status {
    case unknown
    case updateNotAvailable
    case updateAvailable
    case checking(Task<Bool, Error>)
  }

  private let applicationMeta: ApplicationMeta
  private let appVersionsFetchNetworkOperation: AppVersionsFetchNetworkOperation
  private let mdmConfiguration: MDMConfiguration
  private var status: Status = .unknown
  private var latestVersionPageURL: URLString? = .none

  fileprivate init(
    applicationMeta: ApplicationMeta,
    appVersionsFetchNetworkOperation: AppVersionsFetchNetworkOperation,
    mdmConfiguration: MDMConfiguration
  ) {
    self.applicationMeta = applicationMeta
    self.appVersionsFetchNetworkOperation = appVersionsFetchNetworkOperation
    self.mdmConfiguration = mdmConfiguration
  }

  fileprivate func isStatusCheckRequired() async -> Bool {
    if mdmConfiguration.isUpdateCheckDisabled() {
      Diagnostics.shared.logger.info("Update check is disabled by MDM configuration.")
      return false
    }
    switch status {
    case .unknown:
      return true

    case .updateNotAvailable, .updateAvailable:
      return false

    case .checking(let task):
      do {
        _ = try await task.value
        return false
      }
      catch {
        return true
      }
    }
  }

  fileprivate func isUpdateAvailable() async throws -> Bool {
    switch status {
    case .unknown:
      let task: Task<Bool, Error> = Task {
        try checkIfCurrentVersionIsLatest(
          current: currentAppVersion(),
          latest: try await latestAppVersion()
        )
      }
      status = .checking(task)

      let updateAvailable: Bool
      do {
        updateAvailable = try await task.value
      }
      catch {
        status = .unknown
        throw error
      }

      if updateAvailable {
        status = .updateAvailable
      }
      else {
        status = .updateNotAvailable
      }

      return updateAvailable

    case .updateNotAvailable:
      return false

    case .updateAvailable:
      return true

    case .checking(let task):
      return try await task.value
    }
  }

  private func currentAppVersion() -> String {
    self.applicationMeta.applicationVersion()
  }

  fileprivate func updatePageURL() async -> URLString? {
    self.latestVersionPageURL
  }

  private func latestAppVersion() async throws -> String {
    let availableVersions: AppVersionsFetchNetworkOperationResult = try await appVersionsFetchNetworkOperation()

    if let latest: AppVersionsFetchNetworkOperationResult.Result = availableVersions.results.first {
      self.latestVersionPageURL = latest.trackViewUrl.map(URLString.init(rawValue:))
      return latest.version
    }
    else {
      throw ApplicationVersionOutdated.error()
    }
  }

  private func checkIfCurrentVersionIsLatest(
    current: String,
    latest: String
  ) throws -> Bool {
    // assuming semver for both strings X.X.X
    var currentVersionParts: Array<Int> =
      current
      .split(separator: ".")
      .compactMap { Int($0) }
    var latestVersionParts: Array<Int> =
      latest
      .split(separator: ".")
      .compactMap { Int($0) }

    guard
      currentVersionParts.count == latestVersionParts.count,
      let currentPatch: Int = currentVersionParts.popLast(),
      let currentMinor: Int = currentVersionParts.popLast(),
      let currentMajor: Int = currentVersionParts.popLast(),
      let latestPatch: Int = latestVersionParts.popLast(),
      let latestMinor: Int = latestVersionParts.popLast(),
      let latestMajor: Int = latestVersionParts.popLast()
    else { throw ApplicationVersionOutdated.error() }

    guard currentMajor == latestMajor
    else { return currentMajor < latestMajor }
    guard currentMinor == latestMinor
    else { return currentMinor < latestMinor }
    return currentPatch < latestPatch
  }
}
