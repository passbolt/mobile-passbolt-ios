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

/// Access to current session users
/// message encryption.
public struct UsersPGPMessages {

  /// Encrypt a message for each user in the list
  /// by fetching users public keys from a local database.
  public var encryptMessageForUsers:
    @Sendable (
      _ recipients: OrderedSet<User.ID>,
      _ message: String
    ) async throws -> OrderedSet<EncryptedMessage>

  /// Encrypt a message for each user with permission
  /// to the requested resource by fetching users public keys
  /// and resource permissions from a local database.
  public var encryptMessageForResourceUsers:
    @Sendable (
      _ resourceID: Resource.ID,
      _ message: String
    ) async throws -> OrderedSet<EncryptedMessage>

  public var encryptMessageForResourceFolderUsers:
    @Sendable (
      _ resourceFolderID: ResourceFolder.ID,
      _ message: String
    ) async throws -> OrderedSet<EncryptedMessage>

  public init(
    encryptMessageForUsers:
      @escaping @Sendable (
        _ recipients: OrderedSet<User.ID>,
        _ message: String
      ) async throws -> OrderedSet<EncryptedMessage>,
    encryptMessageForResourceUsers:
      @escaping @Sendable (
        _ resourceID: Resource.ID,
        _ message: String
      ) async throws -> OrderedSet<EncryptedMessage>,
    encryptMessageForResourceFolderUsers:
      @escaping @Sendable (
        _ resourceFolderID: ResourceFolder.ID,
        _ message: String
      ) async throws -> OrderedSet<EncryptedMessage>
  ) {
    self.encryptMessageForUsers = encryptMessageForUsers
    self.encryptMessageForResourceUsers = encryptMessageForResourceUsers
    self.encryptMessageForResourceFolderUsers = encryptMessageForResourceFolderUsers
  }
}

extension UsersPGPMessages: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG
  public static var placeholder: Self {
    Self(
      encryptMessageForUsers: unimplemented2(),
      encryptMessageForResourceUsers: unimplemented2(),
      encryptMessageForResourceFolderUsers: unimplemented2()
    )
  }
  #endif
}
