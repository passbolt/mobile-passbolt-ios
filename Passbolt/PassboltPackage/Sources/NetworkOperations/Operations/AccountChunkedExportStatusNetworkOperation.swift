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

public typealias AccountChunkedExportStatusNetworkOperation = NetworkOperation<
  AccountChunkedExportStatusNetworkOperationDescription
>

public enum AccountChunkedExportStatusNetworkOperationDescription: NetworkOperationDescription {
  public typealias Input = AccountChunkedExportStatusNetworkOperationRequestData
  public typealias Output = AccountChunkedExportStatusNetworkOperationResponseData
}

public struct AccountChunkedExportStatusNetworkOperationRequestData {

  public let transferID: String

  public init(
    transferID: String
  ) {
    self.transferID = transferID
  }
}

public struct AccountChunkedExportStatusNetworkOperationResponseData: Decodable {

  public let currentPage: Int
  public let totalPages: Int
  public let status: AccountTransferUpdateNetworkOperationVariable.Status

  public init(
    currentPage: Int,
    totalPages: Int,
    status: AccountTransferUpdateNetworkOperationVariable.Status
  ) {
    self.currentPage = currentPage
    self.totalPages = totalPages
    self.status = status
  }

  public enum CodingKeys: String, CodingKey {

    case currentPage = "current_page"
    case totalPages = "total_pages"
    case status = "status"
  }
}
