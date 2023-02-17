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
  public var updates: UpdatesSequence
  /// Access currently stored profile data
  /// for the context account.
  public var profile: @Sendable () throws -> AccountWithProfile
  /// Fetch profile updates if any.
  /// Requires valid session for context account.
  public var updateProfile: @Sendable () async throws -> Void
  /// Load avatar image data for the context account.
  public var avatarImage: @Sendable () async throws -> Data?

  public init(
    updates: UpdatesSequence,
    profile: @escaping @Sendable () throws -> AccountWithProfile,
    updateProfile: @escaping @Sendable () async throws -> Void,
    avatarImage: @escaping @Sendable () async throws -> Data?
  ) {
    self.updates = updates
    self.profile = profile
    self.updateProfile = updateProfile
    self.avatarImage = avatarImage
  }
}

extension AccountDetails: LoadableFeature {

  public typealias Context = Account

  #if DEBUG
  public static var placeholder: Self {
    Self(
      updates: .placeholder,
      profile: unimplemented0(),
      updateProfile: unimplemented0(),
      avatarImage: unimplemented0()
    )
  }
  #endif
}
