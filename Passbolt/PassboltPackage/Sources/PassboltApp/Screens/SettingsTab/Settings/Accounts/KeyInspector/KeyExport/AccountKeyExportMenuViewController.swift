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

import Display
import OSFeatures
import Accounts
import AccountSetup
import FeatureScopes
import SharedUIComponents

internal final class AccountKeyExportMenuViewController: ViewController {

	private let navigationToOperationAuthorization: NavigationToOperationAuthorization
	private let navigationToExternalActivity: NavigationToExternalActivity
	private let navigationToSelf: NavigationToAccountKeyExportMenu

	private let accountDetails: AccountDetails

	private let features: Features

	internal init(
		context: Void,
		features: Features
	) throws {
		self.features = features

		self.accountDetails = try features.instance()

		self.navigationToOperationAuthorization = try features.instance()
		self.navigationToExternalActivity = try features.instance()
		self.navigationToSelf = try features.instance()
	}
}

extension AccountKeyExportMenuViewController {

	internal func dismiss() async {
		await self.navigationToSelf.revertCatching()
	}

	internal func exportPrivateKey() async {
		await self.navigationToSelf.revertCatching()
		do {
			let features: Features = try self.features.branch(scope: AccountTransferScope.self)
			let accountKeyExport: AccountArmoredKeyExport = try features.instance()
			await self.navigationToOperationAuthorization.performCatching(
				context: .init(
					title: "account.key.export.private.authorization.title",
					actionLabel: "account.key.export.private.authorization.button.title",
					operation: { [self] (authorizationMethod: AccountAuthorizationMethod) in
						try await self.authorizePrivateKeyExport(
							authorizationMethod,
							using: accountKeyExport
						)
					}
				)
			)
		}
		catch {
			error.logged()
		}
	}

	private func authorizePrivateKeyExport(
		_ authorizationMethod: AccountAuthorizationMethod,
		using accountKeyExport: AccountArmoredKeyExport
	) async throws {
		let privateKey: ArmoredPGPPrivateKey = try await accountKeyExport.authorizePrivateKeyExport(authorizationMethod)
		try await navigationToOperationAuthorization.revert()
		try await navigationToExternalActivity.perform(
			context: .share(
				privateKey: privateKey
			)
		)
	}

	internal func exportPublicKey() async {
		await self.navigationToSelf.revertCatching()
		do {
			let publicKey: ArmoredPGPPublicKey = try await self.accountDetails.keyDetails().publicKey
			try await navigationToExternalActivity.perform(
				context: .share(
					publicKey: publicKey
				)
			)
		}
		catch {
			error.logged()
		}
	}
}
