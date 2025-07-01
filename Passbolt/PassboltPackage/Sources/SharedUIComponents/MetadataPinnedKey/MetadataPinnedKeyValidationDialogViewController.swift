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
import Display
import FeatureScopes
import Metadata
import Resources

public final class MetadataPinnedKeyValidationDialogViewController: ViewController {
  public typealias FailureReason = MetadataKeysService.KeyValidationResult.FailureReason

  public struct Context {

    internal let reason: FailureReason
    internal let onTrustedKey: () async throws -> Void
    internal let onCancel: (() async -> Void)?

    public init(
      reason: FailureReason,
      onTrustedKey: @escaping () async throws -> Void,
      onCancel: (() async -> Void)? = .none
    ) {
      self.reason = reason
      self.onTrustedKey = onTrustedKey
      self.onCancel = onCancel
    }
  }

  public struct ViewState: Equatable {
    internal let reason: FailureReason

    internal var isChanged: Bool {
      if case .changed = reason {
        return true
      }

      return false
    }

    private var changeDetails: (FailureReason.ModifiedBy, Fingerprint)? {
      if case .changed(let modifiedBy, let fingerprint) = reason {
        return (modifiedBy, fingerprint)
      }
      return .none
    }

    internal var isDeleted: Bool {
      reason == .deleted
    }

    internal var unknownReason: Bool {
      reason == .unknown
    }

    internal var canTrust: Bool {
      reason != .unknown
    }

    internal var userDisplayName: String? {
      if case .changed(let userDisplayName, _) = reason {
        return userDisplayName.rawValue
      }
      return .none
    }

    internal var formattedFingerprint: String? {
      if case .changed(_, let fingerprint) = reason {
        return fingerprint
          .rawValue
          .split(by: 4)
          .split(by: 5)
          .map { $0.joined(separator: " ") }
          .joined(separator: "\n")
      }
      return .none
    }
  }

  private let metadataKeyService: MetadataKeysService

  private let context: Context

  nonisolated public let viewState: ViewStateSource<ViewState>

  private let features: Features

  public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.features = features

    self.context = context

    self.metadataKeyService = try features.instance()

    self.viewState = .init(
      initial: .init(
        reason: context.reason
      )
    )
  }

  internal func trust() async throws {
    if context.reason == .deleted {
      try await metadataKeyService.removePinnedKey()
    }
    else {
      try await metadataKeyService.trustCurrentKey()
    }
    await revertNavigation()

    try await context.onTrustedKey()
  }

  internal func dismiss() async {
    await context.onCancel?()
    await revertNavigation()
  }

  private func revertNavigation() async {
    await consumingErrors {
      // TODO: This is a workaround to avoid the navigation tree to be used in extension context.
      if isInExtensionContext {
        let navigationTree: NavigationTree = self.features.instance(of: NavigationTree.self)
        await navigationTree.dismiss(self.viewNodeID)
      }
      else {
        let navigationToSelf: NavigationToMetadataPinnedKeyValidationDialog = try self.features.instance()
        await navigationToSelf.revertCatching()
      }
    }
  }
}

extension Fingerprint {
  fileprivate var formatted: String {
    rawValue
      .split(by: 4)
      .split(by: 5)
      .map { $0.joined(separator: " ") }
      .joined(separator: "\n")
  }
}

extension MetadataPinnedKeyValidationDialogViewController.Context {
  fileprivate var userDisplayName: String? {
    if case .changed(let userDisplayName, _) = reason {
      return userDisplayName.rawValue
    }
    return .none
  }

  fileprivate var isKeyDeleted: Bool {
    if case .deleted = reason {
      return true
    }
    return false
  }
}
