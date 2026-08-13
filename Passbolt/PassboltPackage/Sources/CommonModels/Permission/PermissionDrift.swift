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

/// Outcome of comparing a confirmed ``PermissionSnapshot`` against the current server state on confirmation.
/// Each axis mirrors a way a compromised server could expand who a secret is encrypted for after the operator
/// reviewed the recipients. In the first iteration any drift aborts the operation.
public struct PermissionDrift {

  /// The set of (recipient, permission level) differs from the confirmed snapshot.
  public var changedPermissions: Bool
  /// A recipient present in both snapshots has a different key fingerprint (possible key substitution).
  public var changedFingerprints: Bool
  /// A group present in both snapshots has different membership (someone added to an already-permitted group).
  public var changedMemberships: Bool
  /// Display names of the recipients behind the drift, in the order they were found - used to name them in the
  /// message shown to the operator. Empty when the drift cannot be attributed to a named recipient.
  public var changedRecipients: OrderedSet<String>

  public init(
    changedPermissions: Bool,
    changedFingerprints: Bool,
    changedMemberships: Bool,
    changedRecipients: OrderedSet<String> = .init()
  ) {
    self.changedPermissions = changedPermissions
    self.changedFingerprints = changedFingerprints
    self.changedMemberships = changedMemberships
    self.changedRecipients = changedRecipients
  }

  /// Whether any drift was detected.
  public var hasDrift: Bool {
    self.changedPermissions || self.changedFingerprints || self.changedMemberships
  }

  public static let none: Self = .init(
    changedPermissions: false,
    changedFingerprints: false,
    changedMemberships: false
  )
}

extension PermissionDrift: Equatable {}
extension PermissionDrift: Sendable {}

extension PermissionDrift {

  /// Message naming who changed. Falls back to the unattributed message when no recipient could be named - which
  /// is the case for a recipient the server introduced that was never part of the confirmed snapshot.
  public var displayableMessage: DisplayableString {
    guard let first: String = self.changedRecipients.first
    else { return .localized(key: "resource.permission.confirm.drift.message") }

    if self.changedRecipients.count == 1 {
      return .localized(
        key: "resource.permission.confirm.drift.single.message",
        arguments: [first]
      )
    }
    else {
      return .localized(
        key: "resource.permission.confirm.drift.multiple.message",
        arguments: [first]
      )
    }
  }
}
