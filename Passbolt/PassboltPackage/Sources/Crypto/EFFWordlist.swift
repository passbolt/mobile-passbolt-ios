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

import class Foundation.Bundle
import struct Foundation.URL

/// EFF Long Wordlist (7,776 words) for passphrase generation.
/// Source: https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt
internal enum EFFWordlist {

  internal static let words: Array<String> = {
    guard
      let url: URL = Bundle.module.url(forResource: "eff_large_wordlist", withExtension: "txt"),
      let content: String = try? String(contentsOf: url, encoding: .utf8)
    else {
      assertionFailure("EFF wordlist resource not found in bundle")
      return .init()
    }
    return
      content
      .components(separatedBy: .newlines)
      .filter { !$0.isEmpty }
  }()
}
