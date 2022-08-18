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

public typealias SessionCreateNetworkOperation =
  NetworkOperation<SessionCreateNetworkOperationVariable, SessionCreateNetworkOperationResult>

public struct SessionCreateNetworkOperationVariable {

  public var domain: URLString
  public var userID: Account.UserID
  public var challenge: ArmoredPGPMessage
  public var mfaToken: SessionMFAToken?

  public init(
    domain: URLString,
    userID: Account.UserID,
    challenge: ArmoredPGPMessage,
    mfaToken: SessionMFAToken?
  ) {
    self.domain = domain
    self.userID = userID
    self.challenge = challenge
    self.mfaToken = mfaToken
  }
}

public struct SessionCreateNetworkOperationResult {

  public var mfaTokenIsValid: Bool
  public var challenge: ArmoredPGPMessage

  public init(
    mfaTokenIsValid: Bool,
    challenge: ArmoredPGPMessage
  ) {
    self.mfaTokenIsValid = mfaTokenIsValid
    self.challenge = challenge
  }
}
