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

import Crypto
import FeatureScopes
import OSFeatures
import Resources

// MARK: - Implementation

extension TOTPCodeGenerator {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let time: OSTime = features.instance()
    let hotpCodeGenerator: HOTPCodeGenerator = try features.instance(
      context: .init(
        resourceID: context.resourceID,
        sharedSecret: context.totpSecret.sharedSecret,
        algorithm: context.totpSecret.algorithm,
        digits: context.totpSecret.digits
      )
    )

    let rawPeriod: Int64 = context.totpSecret.period.rawValue
    guard rawPeriod > 0
    else { throw InternalInconsistency.error("TOTP period should be greater than zero!") }

    @Sendable nonisolated func generate() -> TOTPValue {
      let rawTimestamp: Int64 = time.timestamp().rawValue
      // ignoring negative time (it will crash)
      let counter: UInt64 = UInt64(rawTimestamp / rawPeriod)

      let hotp: HOTPValue = hotpCodeGenerator.generate(counter)

      return TOTPValue(
        resourceID: context.resourceID,
        otp: hotp.otp,
        timeLeft: .init(
          rawValue: rawPeriod - rawTimestamp % rawPeriod
        ),
        period: context.totpSecret.period
      )
    }

    return .init(
      generate: generate
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltTOTPCodeGenerator() {
    self.use(
      .disposable(
        TOTPCodeGenerator.self,
        load: TOTPCodeGenerator.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
