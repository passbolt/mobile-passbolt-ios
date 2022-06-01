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
import SwiftUI

public struct FingerprintTextView: View {

  private let formattedFingerprint: String

  public init(
    fingerprint: Fingerprint
  ) {
    var formattedString: String = .init()
    var currentIndex: String.Index = fingerprint.rawValue.startIndex
    var newLineCounter: Int = 0
    while true {
      if let nextIndex: String.Index =
        fingerprint.rawValue
        .index(
          currentIndex,
          offsetBy: 4,
          limitedBy: fingerprint.rawValue.endIndex
        )
      {
        if newLineCounter >= 4 {
          formattedString.append("\n")
          newLineCounter = 1
        }
        else {
          newLineCounter += 1
        }
        formattedString.append(
          contentsOf: fingerprint.rawValue[
            currentIndex..<nextIndex
          ]
        )
        formattedString.append(" ")
        currentIndex = nextIndex
        continue
      }
      else {
        if newLineCounter >= 4 {
          formattedString.append("\n")
        }
        else { /* NOP */
        }
        formattedString.append(
          contentsOf: fingerprint.rawValue[
            currentIndex..<fingerprint.rawValue.endIndex
          ]
        )
        break
      }
    }

    self.formattedFingerprint = formattedString
  }

  public var body: some View {
    Text(self.formattedFingerprint)
      .text(
        font: .inconsolata(
          ofSize: 12,
          weight: .regular
        ),
        color: .passboltSecondaryText
      )
      .multilineTextAlignment(.center)
  }
}
