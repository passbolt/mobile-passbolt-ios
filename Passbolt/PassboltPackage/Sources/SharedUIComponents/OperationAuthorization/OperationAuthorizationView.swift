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

internal struct OperationAuthorizationView: ControlledView {

	internal let controller: OperationAuthorizationViewController

	internal init(
		controller: OperationAuthorizationViewController
	) {
		self.controller = controller
	}

	internal var body: some View {
		self.contentView
		.navigationTitle(displayable: self.controller.configuration.title)
		.task{
			await self.controller.authorizeWithBiometrics()
		}
	}

	@ViewBuilder @MainActor private var contentView: some View {
		VStack(spacing: 16) {
			with(\.accountAvatarImage) { (accountAvatarImage) in
				AvatarView(avatarImage: accountAvatarImage)
			}
			.frame(width: 96, height: 96)
			.padding(top: 56)
			.accessibilityIdentifier("authorization.avatar")

			with(\.accountLabel) { (label: String) in
				Text(label)
					.text(
						font: .inter(
							ofSize: 20,
							weight: .semibold
						),
						color: .passboltPrimaryText
					)
			}
			.accessibilityIdentifier("authorization.label")

			with(\.accountUsername) { (username: String) in
				Text(username)
					.text(
						font: .inter(ofSize: 14),
						color: .passboltSecondaryText
					)
			}
			.accessibilityIdentifier("authorization.username")

			with(\.accountDomain) { (domain: String) in
				Text(domain)
					.text(
						font: .inter(ofSize: 14),
						color: .passboltSecondaryText
					)
			}
			.accessibilityIdentifier("authorization.domain")

			withValidatedBinding(
				\.passphrase,
				 updating: self.controller.setPassphrase(_:)
			) { (passphrase: Binding<Validated<String>>) in
				FormSecureTextFieldView(
					title: "authorization.passphrase.description.text",
					prompt: "",
					mandatory: true,
					state: passphrase
				)
			}
			.padding(top: 16)
			.accessibilityIdentifier("authorization.passphrase.input")

			with(\.biometricsAvailability) { (biometricsAvailability) in
				switch biometricsAvailability {
				case .unavailable, .unconfigured:
					EmptyView()

				case .faceID:
					AsyncButton(
						action: self.controller.authorizeWithBiometrics,
						regularLabel: {
							Image(named: .faceID)
								.resizable()
								.padding(10)
						},
						loadingLabel: {
							ZStack {
								Image(named: .faceID)
									.resizable()
									.padding(10)

								SwiftUI.ProgressView()
									.progressViewStyle(.circular)
							}
						}
					)
					.frame(width: 56, height: 56)
					.tint(.passboltPrimaryBlue)
					.overlay(
						Circle()
							.stroke(
								Color.passboltDivider,
								lineWidth: 1
							)
					)
					.accessibilityIdentifier("authorization.biometrics.button")

				case .touchID:
					AsyncButton(
						action: self.controller.authorizeWithBiometrics,
						regularLabel: {
							Image(named: .touchID)
								.resizable()
								.padding(10)
						},
						loadingLabel: {
							ZStack {
								Image(named: .touchID)
									.resizable()
									.padding(10)

								SwiftUI.ProgressView()
									.progressViewStyle(.circular)
							}
						}
					)
					.frame(width: 56, height: 56)
					.tint(.passboltPrimaryBlue)
					.overlay(
						Circle()
							.stroke(
								Color.passboltDivider,
								lineWidth: 1
							)
					)
					.accessibilityIdentifier("authorization.biometrics.button")
				}
			}

			Spacer()

			PrimaryButton(
				title: self.controller.configuration.actionLabel,
				action: self.controller.authorizeWithPassphrase
			)
			.accessibilityIdentifier("authorization.primary.button")
		}
		.padding(16)
	}
}
