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
import Features

// MARK: - Interface

public struct TOTPCodeGenerator {

	public struct Parameters {

		public var resourceID: Resource.ID?
		public var sharedSecret: String
		public var algorithm: HOTPAlgorithm
		public var digits: UInt
		public var period: Seconds

		public init(
			resourceID: Resource.ID?,
			sharedSecret: String,
			algorithm: HOTPAlgorithm,
			digits: UInt,
			period: Seconds
		) {
			self.resourceID = resourceID
			self.sharedSecret = sharedSecret
			self.algorithm = algorithm
			self.digits = digits
			self.period = period
		}

		public init(
			resourceID: Resource.ID?,
			secret: TOTPSecret
		) {
			self.resourceID = resourceID
			self.sharedSecret = secret.sharedSecret
			self.algorithm = secret.algorithm
			self.digits = secret.digits
			self.period = secret.period
		}
	}

	public var prepare: @Sendable (Parameters) -> @Sendable () -> TOTPValue

	public init(
		prepare: @escaping @Sendable (Parameters) -> @Sendable () -> TOTPValue
	) {
		self.prepare = prepare
	}
}

extension TOTPCodeGenerator: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
			prepare: unimplemented1()
    )
  }
  #endif
}
