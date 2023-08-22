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

import NetworkOperations
import struct Foundation.URL

// MARK: Implementation

extension DUOAuthorizationCallbackNetworkOperation {

	@Sendable fileprivate static func requestPreparation(
		_ input: Input
	) -> Mutation<HTTPRequest> {
		.combined(
			.pathSuffix("/mfa/verify/duo/callback"),
			.queryItem("state", value: input.duoToken),
			.queryItem("duo_code", value: input.duoCode),
			.queryItem("mobile", value: "1"),
			.header("Cookie", value: "passbolt_duo_state=\(input.passboltToken)"),
			.method(.get)
		)
	}

	@Sendable fileprivate static func responseDecoder(
		_ input: Input,
		_ response: HTTPResponse
	) throws -> Output {
		guard
			let cookieHeaderValue: String = response.headers["Set-Cookie"],
			let cookieBounds: Range<String.Index> = cookieHeaderValue.range(of: "passbolt_mfa=")
		else {
			throw
				NetworkResponseDecodingFailure
				.error(
					"Failed to find DUO mfa cookie",
					response: response
				)
		}

		return .init(
			mfaToken: .init(
				rawValue: String(
					cookieHeaderValue[cookieBounds.upperBound...]
						.prefix(
							while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
						)
				)
			)
		)
	}
}

extension FeaturesRegistry {

	internal mutating func usePassboltDUOAuthorizationCallbackNetworkOperation() {
		self.use(
			.networkOperationWithSession(
				of: DUOAuthorizationCallbackNetworkOperation.self,
				requestPreparation: DUOAuthorizationCallbackNetworkOperation.requestPreparation(_:),
				responseDecoding: DUOAuthorizationCallbackNetworkOperation.responseDecoder(_:_:)
			)
		)
	}
}
