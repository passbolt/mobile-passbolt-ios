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
import Commons
import Networking

public typealias AccountTransferUpdateRequest
  = NetworkRequest<AccountTransferUpdateRequestVariable, AccountTransferUpdateResponse>

extension AccountTransferUpdateRequest {
  
  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<NetworkSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { _, requestVariable in
        .combined(
          .scheme("https"),
          .host(requestVariable.domain.replacingOccurrences(of: "https://", with: "")),
          .path("/mobile/transfers/\(requestVariable.transferID)/\(requestVariable.authenticationToken).json"),
          .method(.put),
          .header("Content-Type", value: "application/json"),
          .jsonBody(
            from: AccountTransferUpdateRequestVariable.Body(
              currentPage: requestVariable.currentPage,
              status: requestVariable.status
            )
          )
        )
      },
      responseDecoder: .statusCode(200),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct AccountTransferUpdateRequestVariable {
  
  public var domain: String
  public var authenticationToken: String
  public var transferID: String
  public var currentPage: Int
  public var status: Status
  
  public init(
    domain: String,
    authenticationToken: String,
    transferID: String,
    currentPage: Int,
    status: Status
  ) {
    self.domain = domain
    self.authenticationToken = authenticationToken
    self.transferID = transferID
    self.currentPage = currentPage
    self.status = status
  }
}

extension AccountTransferUpdateRequestVariable {
  
  public enum Status: String, Encodable {
    
    case inProgress = "in progress"
    case complete = "complete"
    case error = "error"
    case cancel = "cancel"
  }
  
  public struct Body: Encodable {
    
    public var currentPage: Int
    public var status: Status
    
    internal enum CodingKeys: String, CodingKey {
      
      case currentPage = "current_page"
      case status = "status"
    }
  }
}

public typealias AccountTransferUpdateResponse = Void
