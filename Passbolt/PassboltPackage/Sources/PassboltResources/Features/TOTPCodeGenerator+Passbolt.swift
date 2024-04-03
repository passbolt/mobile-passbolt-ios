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
    features: Features
  ) throws -> Self {
    let time: OSTime = features.instance()
    let hotpCodeGenerator: HOTPCodeGenerator = try features.instance()

    @Sendable nonisolated func prepare(
      with parameters: Parameters
    ) -> @Sendable () -> TOTPValue {
      let rawPeriod: Int64 = parameters.period.rawValue
      guard rawPeriod > 0
      else {
        InternalInconsistency
          .error("TOTP period should be greater than zero!")
          .log()
        return {
          TOTPValue(
            resourceID: parameters.resourceID,
            otp: "",
            timeLeft: 0,
            period: 0
          )
        }
      }

      let hotpGenerator: @Sendable (UInt64) -> HOTPValue = hotpCodeGenerator.prepare(
        .init(
          resourceID: parameters.resourceID,
          sharedSecret: parameters.sharedSecret,
          algorithm: parameters.algorithm,
          digits: parameters.digits
        )
      )

      @Sendable nonisolated func generate() -> TOTPValue {
        let rawTimestamp: Int64 = time.timestamp().rawValue
        // ignoring negative time (it will crash)
        let counter: UInt64 = UInt64(rawTimestamp / rawPeriod)

        let hotp: HOTPValue = hotpGenerator(counter)

        return TOTPValue(
          resourceID: parameters.resourceID,
          otp: hotp.otp,
          timeLeft: .init(
            rawValue: rawPeriod - rawTimestamp % rawPeriod
          ),
          period: parameters.period
        )
      }

      return generate
    }

    return .init(
      prepare: prepare(with:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltTOTPCodeGenerator() {
    self.use(
      .disposable(
        TOTPCodeGenerator.self,
        load: TOTPCodeGenerator.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
