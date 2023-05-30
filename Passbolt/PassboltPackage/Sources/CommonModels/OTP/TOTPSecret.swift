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

import Commons

public struct TOTPSecret {

  public var sharedSecret: String
  public var algorithm: HOTPAlgorithm
  public var digits: UInt
  public var period: Seconds

  public init(
    sharedSecret: String,
    algorithm: HOTPAlgorithm,
    digits: UInt,
    period: Seconds
  ) {
    self.sharedSecret = sharedSecret
    self.algorithm = algorithm
    self.digits = digits
    self.period = period
  }
}

extension TOTPSecret: Sendable {}

extension TOTPSecret: Equatable {}

extension TOTPSecret: Codable {

  private enum CodingKeys: String, CodingKey {

    case sharedSecret = "key"
    case algorithm = "algorithm"
    case digits = "digits"
    case period = "period"
  }
}

extension JSON {

	public var totpSecretValue: TOTPSecret? {
		get {
			if  // searching for predefined structure
				let sharedSecret: String = self.secret_key.stringValue,
				let algorithm: HOTPAlgorithm = self.algorithm.stringValue.flatMap(HOTPAlgorithm.init(rawValue:)),
				let digits: UInt = self.digits.uIntValue,
				let period: Seconds = self.period.int64Value.map(Seconds.init(rawValue:))
			{
				return .init(
					sharedSecret: sharedSecret,
					algorithm: algorithm,
					digits: digits,
					period: period
				)
			}
			else {
				return .none // can't find matching structure
			}
		}
		set {
			if let newValue {
				self.secret_key = .string(newValue.sharedSecret)
				self.algorithm = .string(newValue.algorithm.rawValue)
				self.digits = .integer(newValue.digits)
				self.period = .integer(newValue.period.rawValue)
			}
			else {
				self = .null
			}
		}
	}
}
