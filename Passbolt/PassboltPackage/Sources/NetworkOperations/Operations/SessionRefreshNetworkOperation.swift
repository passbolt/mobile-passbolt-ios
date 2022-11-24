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
import Session

// MARK: - Interface

public typealias SessionRefreshNetworkOperation =
  NetworkOperation<SessionRefreshNetworkOperationDescription>

public enum SessionRefreshNetworkOperationDescription: NetworkOperationDescription {

  public typealias Input = SessionRefreshNetworkOperationVariable
  public typealias Output = SessionRefreshNetworkOperationResult
}

public struct SessionRefreshNetworkOperationVariable {

  public var domain: URLString
  public var userID: Account.UserID
  public var refreshToken: SessionRefreshToken
  public var mfaToken: SessionMFAToken?

  public init(
    domain: URLString,
    userID: Account.UserID,
    refreshToken: SessionRefreshToken,
    mfaToken: SessionMFAToken?
  ) {
    self.domain = domain
    self.userID = userID
    self.refreshToken = refreshToken
    self.mfaToken = mfaToken
  }
}

public struct SessionRefreshNetworkOperationResult {

  public var accessToken: SessionAccessToken
  public var refreshToken: SessionRefreshToken

  public init(
    accessToken: SessionAccessToken,
    refreshToken: SessionRefreshToken
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}
