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

@testable import PassboltAccountSetup

extension AccountTransferConfiguration {

  public static let mock_ada: Self = .init(
    transferID: "TRANSFER_ID",
    pagesCount: 2,
    userID: Account.mock_ada.userID,
    authenticationToken: "TRANSFER_TOKEN",
    domain: Account.mock_ada.domain,
    hash:
      "382f6a26bf10736f89292d59d324885d769f7f1e6968be8ebdc194a9a2e1fe7431c39385d204b234ab8d9f49b8735debbd0fe76c9d987cc32f5963f3e0037d7b"
  )
}
