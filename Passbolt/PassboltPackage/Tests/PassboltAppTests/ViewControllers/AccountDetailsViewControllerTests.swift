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

import FeatureScopes
import TestExtensions
import Features

@testable import Display
@testable import PassboltApp

@available(iOS 16.0.0, *)

final class AccountDetailsViewControllerTests: FeaturesTestCase {
	
	override func commonPrepare() {
		super.commonPrepare()
		set(
			SessionScope.self,
			context: .init(
				account: .mock_ada,
				configuration: .mock_default
			)
		)
		set(
			AccountScope.self,
			context: .mock_ada
		)
		set(SettingsScope.self)
		patch(
			\AccountDetails.updates,
			 with: Variable(initial: Void())
				.asAnyUpdatable()
		)
		patch(
			\AccountDetails.avatarImage,
			 with: always(.none)
		)
		patch(
			\AccountDetails.role,
			 with: always(.none)
		)
	}
	
	func test_viewState_loadsFromAccountDetails() async {
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		
		await withInstance(
			of: AccountDetailsViewController.self,
			returns: AccountDetailsViewController.State(
				avatarImage: .none,
				domain: "https://passbolt.com",
				currentAccountLabel: .valid("Ada Lovelance"),
				name: "Ada Lovelance",
				username: "ada@passbolt.com",
				role: .none
			)
		) { feature in
			await feature.viewState.current
		}
	}
	
	func test_setCurrentAccountLabel_updatesValidValueWhenLabelIsValid() async throws {
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		
		patch(
			\AccountDetails.updates,
			 with: PlaceholderUpdatable().asAnyUpdatable()
		)
		
		await withInstance(
			of: AccountDetailsViewController.self,
			returns: Validated<String>.valid("valid label")
		) { feature in
			await feature.setCurrentAccountLabel("valid label")
			return await feature.viewState.current.currentAccountLabel
		}
	}
	
	func test_setCurrentAccountLabel_updatesInValidValueWhenLabelIsNotValid() async throws {
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		patch(
			\AccountDetails.updates,
			 with: PlaceholderUpdatable().asAnyUpdatable()
		)
		let invalidLabelToSet = "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901"
		
		await withInstance(
			of: AccountDetailsViewController.self,
			returns: Validated<String>.invalid(invalidLabelToSet, error: InvalidForm.error(displayable: "form.field.error.max.length"))
		) { feature in
			await feature.setCurrentAccountLabel(invalidLabelToSet)
			return await feature.viewState.current.currentAccountLabel
		}
	}
	
	func test_saveChanges_fails_whenLabelValidationFails() async throws {
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		patch(
			\AccountDetails.updates,
			 with: PlaceholderUpdatable().asAnyUpdatable()
		)
		let result: UnsafeSendable<String> = .init()
		patch(
			\AccountPreferences.setLocalAccountLabel,
			 with: { store in
				 result.value = store
			 }
		)
		patch(\NavigationToAccountDetails.mockRevert,
					 with: always(self.mockExecuted())
		)
		let invalidLabelToSet = "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901"
		
		await withInstance(
			of: AccountDetailsViewController.self,
			throws: InvalidForm.self
		) { feature in
			await feature.setCurrentAccountLabel(invalidLabelToSet)
			try await feature.saveChanges()
		}
	}
	
	func test_saveChanges_usesDefaultLabel_whenLabelIsEmpty() async throws {
		let result: UnsafeSendable<String> = .init()
		patch(
			\AccountDetails.profile,
			 with: always(.mockWith(.mock_ada, label: ""))
		)
		patch(
			\AccountPreferences.setLocalAccountLabel,
			 with: { store in
				 result.value = store
			 }
		)
		patch(\NavigationToAccountDetails.mockRevert,
					 with: always(self.mockExecuted())
		)
		
		await withInstance(
			of: AccountDetailsViewController.self,
			returns: Optional("Ada Lovelance")
		) { feature in
			try await feature.saveChanges()
			return result.value
		}
	}
	
	func test_saveChanges_fails_whenLabelSaveFails() async throws {
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		patch(
			\AccountPreferences.setLocalAccountLabel,
			 with: alwaysThrow(MockIssue.error())
		)
		
		patch(\NavigationToAccountDetails.mockRevert,
					 with: always(self.mockExecuted())
		)
		
		await withInstance(
			of: AccountDetailsViewController.self,
			throws: MockIssue.self
			
		) { feature in
			try await feature.saveChanges()
		}
	}
	
	func test_saveChanges_succeeds_whenLabelSaveSucceeds() async throws {
		let accountLabelToSet = "Test current account label"
		let result: UnsafeSendable<String> = .init()
		patch(
			\AccountDetails.profile,
			 with: always(.mock_ada)
		)
		patch(
			\AccountPreferences.setLocalAccountLabel,
			 with: { store in
				 result.value = store
			 }
		)
		patch(\NavigationToAccountDetails.mockRevert,
					 with: always(self.mockExecuted())
		)
		patch(
			\AccountDetails.updates,
			 with: PlaceholderUpdatable().asAnyUpdatable()
		)
		
		await withInstance(
			of: AccountDetailsViewController.self,
			returns: Optional(accountLabelToSet)
		) { feature in
			await feature.setCurrentAccountLabel(accountLabelToSet)
			try await feature.saveChanges()
			return result.value
		}
	}
}
