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
import Commons
import Foundation

extension TheErrorLegacy {

  internal static func pgpError(
    _ error: NSError?
  ) -> Self {
    Self(
      identifier: .pgpError,
      underlyingError: error,
      extensions: [:]
    )
  }

  internal static func invalidPassphraseError(underlyingError: Error? = nil) -> Self {
    Self(
      identifier: .invalidPassphraseError,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }

  internal static func invalidInputDataError() -> Self {
    Self(
      identifier: .invalidInputDataError,
      underlyingError: nil,
      extensions: [:]
    )
  }

  internal static func failedToGetPGPFingerprint(
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .failedToGetPGPFingerprint,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }

  internal static func pgpFingerprintMismatch(
    underlyingError: Error? = nil
  ) -> Self {
    Self(
      identifier: .pgpFingerprintMismatch,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }
}

extension TheErrorLegacy.ID {

  public static var pgpError: Self { "pgpError" }
  public static var invalidPassphraseError: Self { "invalidPassphraseError" }
  public static var invalidInputDataError: Self { "invalidInputDataError" }
  public static var failedToGetPGPFingerprint: Self { "failedToGetPGPFingerprint" }
  public static var pgpFingerprintMismatch: Self { "pgpFingerprintMismatch" }
}

extension TheErrorLegacy.Extension {

  public static let invalidFingerprint: Self = "invalidFingerprint"
}

extension TheErrorLegacy {

  public var invalidFingerprint: Fingerprint? { extensions[.invalidFingerprint] as? Fingerprint }
}
