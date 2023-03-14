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
import Features

// MARK: - Interface

public struct OTPResources {

  /// Sequence indicating updates in the list data.
  /// It won't contain updates in actual OTP codes.
  public var updates: UpdatesSequence
  /// Refresh resources data.
  /// Current implementation uses SessionData.refreshIfNeeded.
  public var refreshIfNeeded: @Sendable () async throws -> Void
  /// List of OTP resources matching filter.
  public var filteredList: @Sendable (OTPResourcesFilter) async throws -> Array<OTPResourceListItemDSV>
  /// Access part of the resource secret associated with OTP.
  /// Note that secret is not directly cached,
  /// each access to secret will request whole
  /// resource secret from the backend.
  public var secretFor: @Sendable (Resource.ID) async throws -> OTPSecret

  public init(
    updates: UpdatesSequence,
    refreshIfNeeded: @escaping @Sendable () async throws -> Void,
    filteredList: @escaping @Sendable (OTPResourcesFilter) async throws -> Array<OTPResourceListItemDSV>,
    secretFor: @escaping @Sendable (Resource.ID) async throws -> OTPSecret
  ) {
    self.updates = updates
    self.refreshIfNeeded = refreshIfNeeded
    self.filteredList = filteredList
    self.secretFor = secretFor
  }
}

extension OTPResources: LoadableFeature {

  #if DEBUG
  public static var placeholder: Self {
    .init(
      updates: .placeholder,
      refreshIfNeeded: unimplemented0(),
      filteredList: unimplemented1(),
      secretFor: unimplemented1()
    )
  }
  #endif
}
