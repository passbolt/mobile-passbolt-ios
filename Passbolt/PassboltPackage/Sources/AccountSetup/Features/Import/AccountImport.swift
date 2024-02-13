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
import CommonModels
import Features

import struct Foundation.Data

public struct AccountImport {
  // Publishes progess, finishes when process is completed or fails if it becomes interrupted.
  public var progressPublisher: () -> AnyPublisher<Progress, Error>
  public var accountDetailsPublisher: () -> AnyPublisher<AccountDetails, Error>
  public var processPayload: (String) -> AnyPublisher<Never, Error>
  public var completeTransfer: (Passphrase) -> AnyPublisher<Never, Error>
  public var avatarPublisher: () -> AnyPublisher<Data, Error>
  public var checkIfAccountExist: (AccountTransferData) -> Bool
  public var importAccountByPayload: (AccountTransferData) -> Void
  public var cancelTransfer: () -> Void

  public init(
    progressPublisher: @escaping () -> AnyPublisher<Progress, Error>,
    accountDetailsPublisher: @escaping () -> AnyPublisher<AccountDetails, Error>,
    processPayload: @escaping (String) -> AnyPublisher<Never, Error>,
    completeTransfer: @escaping (Passphrase) -> AnyPublisher<Never, Error>,
    avatarPublisher: @escaping () -> AnyPublisher<Data, Error>,
    checkIfAccountExist: @escaping (AccountTransferData) -> Bool,
    importAccountByPayload: @escaping (AccountTransferData) -> Void,
    cancelTransfer: @escaping () -> Void
  ) {
    self.progressPublisher = progressPublisher
    self.accountDetailsPublisher = accountDetailsPublisher
    self.processPayload = processPayload
    self.completeTransfer = completeTransfer
    self.avatarPublisher = avatarPublisher
    self.checkIfAccountExist = checkIfAccountExist
    self.importAccountByPayload = importAccountByPayload
    self.cancelTransfer = cancelTransfer
  }
}

extension AccountImport {

  public struct AccountDetails {

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

  public enum Progress {

    case configuration
    case scanningProgress(Double)
    case scanningFinished
  }
}

extension AccountImport: LoadableFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      progressPublisher: unimplemented0(),
      accountDetailsPublisher: unimplemented0(),
      processPayload: unimplemented1(),
      completeTransfer: unimplemented1(),
      avatarPublisher: unimplemented0(),
      checkIfAccountExist: unimplemented1(),
      importAccountByPayload: unimplemented1(),
      cancelTransfer: unimplemented0()
    )
  }
  #endif
}
