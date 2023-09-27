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
import struct Foundation.Date

public struct PGPKeyDetails {

	public let publicKey: ArmoredPGPPublicKey
	public let userID: String
	public let fingerprint: Fingerprint
	public let length: Int
	public let algorithm: KeyAlgorithm
	public let created: Date
	public let expires: Date?

	public init(
		publicKey: ArmoredPGPPublicKey,
		userID: String,
		fingerprint: Fingerprint,
		length: Int,
		algorithm: KeyAlgorithm,
		created: Date,
		expires: Date?
	) {
		self.publicKey = publicKey
		self.userID = userID
		self.fingerprint = fingerprint
		self.length = length
		self.algorithm = algorithm
		self.created = created
		self.expires = expires
	}
}

extension PGPKeyDetails: Decodable {

	public enum CodingKeys: String, CodingKey {

		case publicKey = "armored_key"
		case userID = "uid"
		case fingerprint = "fingerprint"
		case length = "bits"
		case algorithm = "type"
		case created = "created"
		case expires = "expires"
	}
}

extension PGPKeyDetails: Equatable {}

public enum FingerprintTag {}
public typealias Fingerprint = Tagged<String, FingerprintTag>

public enum KeyAlgorithmTag {}
public typealias KeyAlgorithm = Tagged<String, KeyAlgorithmTag>
