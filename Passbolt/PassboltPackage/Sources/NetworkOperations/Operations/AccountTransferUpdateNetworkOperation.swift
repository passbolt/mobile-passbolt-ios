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

import Features

// MARK: - Interface

public typealias AccountTransferUpdateNetworkOperation =
  NetworkOperation<AccountTransferUpdateNetworkOperationDescription>

public enum AccountTransferUpdateNetworkOperationDescription: NetworkOperationDescription {

  public typealias Input = AccountTransferUpdateNetworkOperationVariable
  public typealias Output = AccountTransferUpdateNetworkOperationResult
}

public struct AccountTransferUpdateNetworkOperationVariable {

  public var domain: URLString
  public var authenticationToken: String
  public var transferID: String
  public var currentPage: Int
  public var status: Status
  public var requestUserProfile: Bool

  public init(
    domain: URLString,
    authenticationToken: String,
    transferID: String,
    currentPage: Int,
    status: Status,
    requestUserProfile: Bool
  ) {
    self.domain = domain
    self.authenticationToken = authenticationToken
    self.transferID = transferID
    self.currentPage = currentPage
    self.status = status
    self.requestUserProfile = requestUserProfile
  }
}

extension AccountTransferUpdateNetworkOperationVariable {

  public enum Status: String, Codable {

    case start = "start"
    case inProgress = "in progress"
    case complete = "complete"
    case error = "error"
    case cancel = "cancel"
  }
}

public struct AccountTransferUpdateNetworkOperationResult: Decodable {

  public var user: User?

  public init(
    user: User?
  ) {
    self.user = user
  }
}

extension AccountTransferUpdateNetworkOperationResult {

  public struct User: Decodable {

    public var username: String
    public var profile: UserProfileDTO
  }
}
