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

import Accounts

import struct Foundation.Data

public struct AccountImport: Sendable {

  public var updates: AnyUpdatable<Void>
  public var progress: @Sendable () -> Progress
  public var accountDetails: @Sendable () -> AccountDetails?
  public var avatar: @Sendable () -> Data?
  public var processPayload: @Sendable (String) async throws -> Void
  public var completeTransfer: @Sendable (Passphrase) async throws -> Void
  public var checkIfAccountExist: @Sendable (AccountTransferData) -> Bool
  public var importAccountByPayload: @Sendable (AccountTransferData) -> Void
  public var cancelTransfer: @Sendable () -> Void

  public init(
    updates: AnyUpdatable<Void>,
    progress: @escaping @Sendable () -> Progress,
    accountDetails: @escaping @Sendable () -> AccountDetails?,
    avatar: @escaping @Sendable () -> Data?,
    processPayload: @escaping @Sendable (String) async throws -> Void,
    completeTransfer: @escaping @Sendable (Passphrase) async throws -> Void,
    checkIfAccountExist: @escaping @Sendable (AccountTransferData) -> Bool,
    importAccountByPayload: @escaping @Sendable (AccountTransferData) -> Void,
    cancelTransfer: @escaping @Sendable () -> Void
  ) {
    self.updates = updates
    self.progress = progress
    self.accountDetails = accountDetails
    self.avatar = avatar
    self.processPayload = processPayload
    self.completeTransfer = completeTransfer
    self.checkIfAccountExist = checkIfAccountExist
    self.importAccountByPayload = importAccountByPayload
    self.cancelTransfer = cancelTransfer
  }
}

extension AccountImport {

  public struct AccountDetails: Equatable, Sendable {

    public let domain: URLString
    public let label: String
    public let username: String

    public init(
      domain: URLString,
      label: String,
      username: String
    ) {
      self.domain = domain
      self.label = label
      self.username = username
    }
  }
}

extension AccountImport {

  public enum Progress: Sendable {

    case configuration
    case scanningProgress(Double)
    case scanningFinished
  }
}

extension AccountImport: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      updates: PlaceholderUpdatable().asAnyUpdatable(),
      progress: unimplemented0(),
      accountDetails: unimplemented0(),
      avatar: unimplemented0(),
      processPayload: unimplemented1(),
      completeTransfer: unimplemented1(),
      checkIfAccountExist: unimplemented1(),
      importAccountByPayload: unimplemented1(),
      cancelTransfer: unimplemented0()
    )
  }
  #endif
}
