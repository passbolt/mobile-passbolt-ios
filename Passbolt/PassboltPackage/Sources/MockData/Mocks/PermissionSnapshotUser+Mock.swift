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

// swift-format-ignore: AlwaysUseLowerCamelCase
extension PermissionSnapshotUser {

  /// A recipient the snapshot describes well enough to encrypt for: it carries a key and a fingerprint. Which
  /// recipients a snapshot describes is what tells one added by hand apart from one already holding a permission,
  /// so this is parametrised by identity rather than canned per user.
  ///
  /// The fingerprint and key are what drift detection compares, so both are overridable - a recipient whose key
  /// rotated between two captures is the same recipient with a different fingerprint.
  public static func mock(
    id: User.ID,
    fingerprint: Fingerprint = "FP",
    publicKey: ArmoredPGPPublicKey = "KEY"
  ) -> Self {
    .init(
      details: .init(
        id: id,
        username: "user@passbolt.com",
        firstName: "First",
        lastName: "Last",
        fingerprint: fingerprint,
        avatarImageURL: "https://passbolt.com/avatar",
        isSuspended: false
      ),
      publicKey: publicKey
    )
  }

  public static let mock_ada: Self = .mock(id: .mock_ada)

  public static let mock_1: Self = .mock(id: .mock_1)
}
