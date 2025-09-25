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

// swift-format-ignore: AlwaysUseLowerCamelCase
extension ArmoredPGPPublicKey {

  public static let mock_ada: Self = .init(
    rawValue: """
      -----BEGIN PGP PUBLIC KEY BLOCK-----

      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
      =Kwft
      -----END PGP PUBLIC KEY BLOCK-----
      """
  )

  public static let mock_frances: Self = .init(
    rawValue: """
      -----BEGIN PGP PUBLIC KEY BLOCK-----

      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
      =82jm
      -----END PGP PUBLIC KEY BLOCK-----
      """
  )
}
