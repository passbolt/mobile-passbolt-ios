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

// swift-format-ignore: AlwaysUseLowerCamelCase
extension AccountTransferConfiguration {

  public static let mock_ada: Self = .init(
    transferID: "TRANSFER_ID",
    pagesCount: 2,
    userID: Account.mock_ada.userID,
    authenticationToken: "TRANSFER_TOKEN",
    domain: Account.mock_ada.domain,
    hash:
      "c6ed55cdbc7b97aaf2b9f6445a20ea11a659962f7eef22b83ec65dc212f7e505e1996969af949dda25dfecd7f482cff7ea4ca744322bdd22b67d6437eae91c6a"
  )
}
