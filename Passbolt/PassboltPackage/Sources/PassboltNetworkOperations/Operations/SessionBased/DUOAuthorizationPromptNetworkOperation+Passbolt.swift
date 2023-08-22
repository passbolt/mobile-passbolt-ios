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

extension DUOAuthorizationPromptNetworkOperation {

	@Sendable fileprivate static func requestPreparation(
		_ input: Input
	) -> Mutation<HTTPRequest> {
		.combined(
			.pathSuffix("/mfa/verify/duo/prompt"),
			.queryItem("mobile", value: "1"),
			.method(.post)
		)
	}

	@Sendable fileprivate static func responseDecoder(
		_ input: Input,
		_ response: HTTPResponse
	) throws -> Output {
		guard
			let redirectURL: URL = response.headers["Location"].flatMap(URL.init(string:))
		else {
			throw
				NetworkResponseDecodingFailure
				.error(
					"Failed to find DUO redirect URL",
					response: response
				)
		}

		guard
			let cookieHeaderValue: String = response.headers["Set-Cookie"],
			let cookieBounds: Range<String.Index> = cookieHeaderValue.range(of: "passbolt_duo_state=")
		else {
			throw
				NetworkResponseDecodingFailure
				.error(
					"Failed to find DUO state cookie",
					response: response
				)
		}

		return .init(
			authorizationURL: redirectURL,
			stateID: String(
				cookieHeaderValue[cookieBounds.upperBound...]
					 .prefix(
						 while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
					 )
			 )
		)
	}
}

extension FeaturesRegistry {

	internal mutating func usePassboltDUOAuthorizationPromptNetworkOperation() {
		self.use(
			.networkOperationWithSession(
				of: DUOAuthorizationPromptNetworkOperation.self,
				requestPreparation: DUOAuthorizationPromptNetworkOperation.requestPreparation(_:),
				responseDecoding: DUOAuthorizationPromptNetworkOperation.responseDecoder(_:_:)
			)
		)
	}
}
