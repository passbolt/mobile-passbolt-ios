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

import Combine
import CommonModels
import Features

import struct Foundation.Data
import struct Foundation.URL

/// Access to details associated with a stored account.
public struct AccountDetails {

  /// Updates in the context account details.
  public var updates: AnyUpdatable<Void>
  /// Access currently stored profile data
  /// for the context account.
  public var profile: @Sendable () throws -> AccountWithProfile
	public var isPassphraseStored: @Sendable () -> Bool
  /// Fetch profile updates if any.
  /// Requires valid session for context account.
  public var updateProfile: @Sendable () async throws -> Void
	/// Fetch account key public details.
	public var keyDetails: @Sendable () async throws -> PGPKeyDetails
    /// Fetch account profile role
    public var role: @Sendable () async throws -> String?
  /// Load avatar image data for the context account.
  public var avatarImage: @Sendable () async throws -> Data?

  public init(
    updates: AnyUpdatable<Void>,
    profile: @escaping @Sendable () throws -> AccountWithProfile,
		isPassphraseStored: @escaping @Sendable () -> Bool,
    updateProfile: @escaping @Sendable () async throws -> Void,
		keyDetails: @escaping @Sendable () async throws -> PGPKeyDetails,
    role: @escaping @Sendable () async throws -> String?,
    avatarImage: @escaping @Sendable () async throws -> Data?
  ) {
    self.updates = updates
    self.profile = profile
		self.isPassphraseStored = isPassphraseStored
    self.updateProfile = updateProfile
		self.keyDetails = keyDetails
    self.avatarImage = avatarImage
      self.role = role
  }
}

extension AccountDetails: LoadableFeature {

  public typealias Context = Account

  #if DEBUG
  public static var placeholder: Self {
    Self(
      updates: PlaceholderUpdatable().asAnyUpdatable(),
      profile: unimplemented0(),
			isPassphraseStored: unimplemented0(),
      updateProfile: unimplemented0(),
      keyDetails: unimplemented0(), 
      role: unimplemented0(),
      avatarImage: unimplemented0()
    )
  }
  #endif
}
