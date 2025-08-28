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

public struct PaginatedResponse<Results>: Sendable
where Results: Collection, Results: Sendable, Results.Element: Sendable {

  public let items: Results
  public let pagination: PaginationData

  public init(items: Results, pagination: PaginationData) {
    self.items = items
    self.pagination = pagination
  }

  public var totalPages: Int {
    guard self.pagination.limit > 0 else {
      return 1
    }

    // round up to the higher integer
    return (self.pagination.count + self.pagination.limit - 1) / self.pagination.limit
  }
}

extension CommonNetworkResponse where Body: Collection, Body.Element: Sendable {

  public var paginatedResponse: PaginatedResponse<Body> {
    get throws {
      guard let paginationData: PaginationData = self.header.pagination
      else {
        throw NoPaginationData.error()
      }

      return .init(items: self.body, pagination: paginationData)
    }
  }
}

public struct NoPaginationData: TheError {

  public static func error(
    _ message: StaticString = "NoPaginationData",
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          message,
          file: file,
          line: line
        )
      ),
      displayableMessage: .localized(key: "error.internal.inconsistency")
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
}
