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

import struct Foundation.Data

public struct AccountTransfer {
  // Publishes progess, finishes when process is completed or fails if it becomes interrupted.
  public var progressPublisher: () -> AnyPublisher<Progress, Error>
  public var accountDetailsPublisher: () -> AnyPublisher<AccountDetails, Error>
  public var processPayload: (String) -> AnyPublisher<Never, Error>
  public var completeTransfer: (Passphrase) -> AnyPublisher<Never, Error>
  public var avatarPublisher: () -> AnyPublisher<Data, Error>
  public var cancelTransfer: () -> Void
  public var featureUnload: @MainActor () async throws -> Void

  public init(
    progressPublisher: @escaping () -> AnyPublisher<Progress, Error>,
    accountDetailsPublisher: @escaping () -> AnyPublisher<AccountDetails, Error>,
    processPayload: @escaping (String) -> AnyPublisher<Never, Error>,
    completeTransfer: @escaping (Passphrase) -> AnyPublisher<Never, Error>,
    avatarPublisher: @escaping () -> AnyPublisher<Data, Error>,
    cancelTransfer: @escaping () -> Void,
    featureUnload: @MainActor @escaping () async throws -> Void
  ) {
    self.progressPublisher = progressPublisher
    self.accountDetailsPublisher = accountDetailsPublisher
    self.processPayload = processPayload
    self.completeTransfer = completeTransfer
    self.avatarPublisher = avatarPublisher
    self.cancelTransfer = cancelTransfer
    self.featureUnload = featureUnload
  }
}

extension AccountTransfer {

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

extension AccountTransfer {

  public enum Progress {

    case configuration
    case scanningProgress(Double)
    case scanningFinished
  }
}

extension AccountTransfer: LoadableFeature {

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      progressPublisher: unimplemented("You have to provide mocks for used methods"),
      accountDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      processPayload: unimplemented("You have to provide mocks for used methods"),
      completeTransfer: unimplemented("You have to provide mocks for used methods"),
      avatarPublisher: unimplemented("You have to provide mocks for used methods"),
      cancelTransfer: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
