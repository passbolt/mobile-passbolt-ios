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

internal struct AccountKeyInspectorView: ControlledView {

	internal var controller: AccountKeyInspectorViewController

	internal init(
		controller: AccountKeyInspectorViewController
	) {
		self.controller = controller
	}

	internal var body: some View {
		withSnackBarMessage(\.snackBarMessage) {
			VStack(spacing: 0) {
				self.headerView
					.padding(
						top: 16,
						bottom: 16
					)
				CommonList {
					self.propertiesView
				}
			}
		}
		.navigationTitle(displayable: "account.key.inspector.title")
		.toolbar {
			ToolbarItemGroup(placement: .navigationBarTrailing) {
				IconButton(
					iconName: .more,
					action: self.controller.showExportMenu
				)
			}
		}
	}

	@MainActor @ViewBuilder private var headerView: some View {
		VStack(spacing: 16) {
			self.with(\.avatarImage) { (avatarImage: Data?) in
				AvatarView(avatarImage: avatarImage)
			}
			.frame(
				width: 96,
				height: 96,
				alignment: .center
			)

			self.with(\.name) { (name: String) in
				Text(name)
			}
			.text(
				font: .inter(
					ofSize: 20,
					weight: .semibold
				),
				color: .passboltPrimaryText
			)
		}
	}

	@MainActor @ViewBuilder private var propertiesView: some View {
		CommonListSection {
			CommonListRow(
				contentAction: self.controller.copyUserID,
				content: {
					self.with(\.userID) { (userID: String) in
						ResourceFieldView(
							name: "account.key.inspector.field.uid.title",
							value: userID
						)
					}
				},
				accessoryAction: self.controller.copyUserID,
				accessory: CopyButtonImage.init
			)

			CommonListRow(
				contentAction: self.controller.copyFingerprint,
				content: {
					ResourceFieldView(
						name: "account.key.inspector.field.fingerprint.title",
						content: {
							self.with(\.fingerprint) { (fingerprint: String) in
								Text(fingerprint)
									.text(
										.leading,
										lines: .none,
										font: .inconsolata(
											ofSize: 14,
											weight: .regular
										),
										color: .passboltSecondaryText
									)
							}
						}
					)
				},
				accessoryAction: self.controller.copyFingerprint,
				accessory: CopyButtonImage.init
			)

			CommonListRow(
				content: {
					self.with(\.crationDate) { (crationDate: String) in
						ResourceFieldView(
							name: "account.key.inspector.field.created.title",
							value: crationDate
						)
					}
				}
			)

			CommonListRow(
				content: {
					self.with(\.expirationDate) { (expirationDate: String?) in
						ResourceFieldView(
							name: "account.key.inspector.field.expires.title",
							value: expirationDate ?? DisplayableString
								.localized(key: "account.key.inspector.no.exipire.placeholder")
							 .string()
						)
					}
				}
			)

			CommonListRow(
				content: {
					self.with(\.keySize) { (keySize: String) in
						ResourceFieldView(
							name: "account.key.inspector.field.key.size.title",
							value: keySize
						)
					}
				}
			)

			CommonListRow(
				content: {
					self.with(\.algorithm) { (algorithm: String) in
						ResourceFieldView(
							name: "account.key.inspector.field.algorithm.title",
							value: algorithm
						)
					}
				}
			)
		}
	}
}
