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

public struct MetadataKeyDataStore {
  public var loadPinnedMetadataKey: @Sendable (Account.LocalID) throws -> JSON?
  public var storePinnedMetadataKey: @Sendable (JSON, Account.LocalID) throws -> Void
  public var deletePinnedMetadataKey: @Sendable (Account.LocalID) throws -> Void

  public init(
    loadPinnedMetadataKey: @escaping @Sendable (Account.LocalID) throws -> JSON?,
    storePinnedMetadataKey: @escaping @Sendable (JSON, Account.LocalID) throws -> Void,
    deletePinnedMetadataKey: @escaping @Sendable (Account.LocalID) throws -> Void
  ) {
    self.loadPinnedMetadataKey = loadPinnedMetadataKey
    self.storePinnedMetadataKey = storePinnedMetadataKey
    self.deletePinnedMetadataKey = deletePinnedMetadataKey
  }
}

extension MetadataKeyDataStore: LoadableFeature {
  #if DEBUG
  public static var placeholder: Self {
    .init(
      loadPinnedMetadataKey: unimplemented1(),
      storePinnedMetadataKey: unimplemented2(),
      deletePinnedMetadataKey: unimplemented1()
    )
  }
  #endif
}
