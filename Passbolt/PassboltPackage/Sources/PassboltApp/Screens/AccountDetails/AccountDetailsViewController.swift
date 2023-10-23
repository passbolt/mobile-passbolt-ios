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
import Accounts

internal final class AccountDetailsViewController: ViewController {

	internal struct State: Equatable {
		internal var avatarImage: Data?
		internal var domain: String
		internal var currentAccountLabel: Validated<String>
		internal var name: String
		internal var username: String
		internal var role: String?
	}

	internal let viewState: ViewStateSource<State>
	private let features: Features

	private let accountDetails: AccountDetails
	private let accountPreferences: AccountPreferences
	private let navigationToTransferInfo: NavigationToTransferInfo
	private let navigationToSelf: NavigationToAccountDetails

	private let accountLabelValidator: Validator<String> =
		.maxLength(
			80,
			displayable: .localized(
				key: "form.field.error.max.length"
			)
		)

	internal init(
		context: Void,
		features: Features
	) throws {
		self.features = features
		self.accountDetails = try features.instance()
		self.accountPreferences = try features.instance()

		self.navigationToTransferInfo = try features.instance()
		self.navigationToSelf = try features.instance()

		self.viewState = .init(
			initial:
					.init(
						avatarImage: .none,
						domain: "",
						currentAccountLabel: .valid(""),
						name: "",
						username: "",
						role: .none
					),
			updateFrom: accountDetails.updates,
			update: { [accountDetails] (updateView, _) in
				do {
					let accountWithProfile: AccountWithProfile = try accountDetails.profile()
					updateView { (viewState: inout State) in
						viewState.name = "\(accountWithProfile.firstName) \(accountWithProfile.lastName)"
						viewState.username = accountWithProfile.username
						viewState.currentAccountLabel = .valid(accountWithProfile.label)
						viewState.domain = accountWithProfile.domain.rawValue
					}

					let role: String? = try await accountDetails.role()
					updateView { (viewState: inout State) in
						viewState.role = role
					}

					let accountAvatarImage: Data? = try await accountDetails.avatarImage()
					updateView { (viewState: inout State) in
						viewState.avatarImage = accountAvatarImage
					}
				}
				catch {
					error.consume(
						context: "Failed to update account details!"
					)
				}
			})
	}
}
extension AccountDetailsViewController {

	internal func saveChanges() async throws {
		let currentAccountLabel = await viewState.current.currentAccountLabel
		let label: String
		if currentAccountLabel.value.isEmpty {
			let currentName = await viewState.current.name
			label = currentName
		}
		else if currentAccountLabel.isValid {
			label = currentAccountLabel.value
		}
		else {
			throw InvalidForm
				.error(
					displayable: .localized(
						key: "form.error.invalid"
					)
				)
		}
		try accountPreferences.setLocalAccountLabel(label)
		try await self.navigationToSelf.revert()
	}

	internal func transferAccount() async throws {
		try await self.navigationToTransferInfo.perform(context: .export)
	}
}

extension AccountDetailsViewController {

	internal final func setCurrentAccountLabel(
		_ label: String
	) {
		self.viewState.update { (state: inout ViewState) in
			state.currentAccountLabel = accountLabelValidator.validate(label)
		}
	}
}
