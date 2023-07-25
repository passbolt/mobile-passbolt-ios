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
import SwiftUI

public struct CommonListResourceView<AccessoryView>: View where AccessoryView: View {

	private let name: String
	private let username: String?
	private let contentAction: @MainActor () async -> Void
	private let accessoryAction: (@MainActor () async -> Void)?
	private let accessory: @MainActor () -> AccessoryView

	public init(
		name: String,
		username: String? = .none,
		contentAction: @escaping @MainActor () async -> Void,
		accessoryAction: (@MainActor () async -> Void)? = .none,
		@ViewBuilder accessory: @escaping @MainActor () -> AccessoryView
	) {
		self.name = name
		self.username = username
		self.contentAction = contentAction
		self.accessoryAction = accessoryAction
		self.accessory = accessory
	}

	public init(
		name: String,
		username: String? = .none,
		contentAction: @escaping @MainActor () async -> Void
	) where AccessoryView == EmptyView {
		self.name = name
		self.username = username
		self.contentAction = contentAction
		self.accessoryAction = .none
		self.accessory = EmptyView.init
	}

	public var body: some View {
		CommonListRow(
			contentAction: self.contentAction,
			content: {
				HStack(spacing: 8) {
					LetterIconView(text: self.name)
						.frame(
							width: 40,
							height: 40,
							alignment: .center
						)

					VStack(alignment: .leading, spacing: 4) {
						Text(name)
							.font(.inter(ofSize: 14, weight: .semibold))
							.lineLimit(1)
							.foregroundColor(Color.passboltPrimaryText)
						Text(
							self.username
								?? DisplayableString
								.localized(key: "resource.list.username.empty.placeholder")
								.string()
						)
						.font(
							self.username == nil
								? .interItalic(ofSize: 12, weight: .regular)
								: .inter(ofSize: 12, weight: .regular)

						)
						.lineLimit(1)
						.foregroundColor(Color.passboltSecondaryText)
					}
				}
				.frame(height: 64)
			},
			accessoryAction: self.accessoryAction,
			accessory: self.accessory
		)
	}
}

#if DEBUG

internal struct CommonListResourceView_Previews: PreviewProvider {

	internal static var previews: some View {
		CommonList {
			CommonListSection {
				CommonListResourceView(
					name: "Resource",
					username: "some username",
					contentAction: {
						print("contentAction")
					},
					accessory: EmptyView.init
				)

				CommonListResourceView(
					name: "Resource",
					contentAction: {
						print("contentAction")
					},
					accessory: EmptyView.init
				)

				CommonListResourceView(
					name: "Very long name which will surely not fit in one line of text and should be truncated",
					username: "Very long username which will surely not fit in one line of text and should be truncated",
					contentAction: {
						print("contentAction")
					},
					accessory: EmptyView.init
				)

				CommonListResourceView(
					name: "Resource",
					username: "username",
					contentAction: {
						print("contentAction")
					},
					accessory: {
						Image(named: .chevronRight)
					}
				)

				CommonListResourceView(
					name: "Resource",
					username: "username",
					contentAction: {
						print("contentAction")
					},
					accessoryAction: {
						print("accessoryAction")
					},
					accessory: {
						Image(named: .more)
					}
				)

				CommonListResourceView(
					name: "Very long name which will surely not fit in one line of text and should be truncated",
					username: "Very long username which will surely not fit in one line of text and should be truncated",
					contentAction: {
						print("contentAction")
					},
					accessoryAction: {
						print("accessoryAction")
					},
					accessory: {
						Image(named: .more)
					}
				)

				CommonListResourceView(
					name: "Resource",
					username: "username",
					contentAction: {
						print("contentAction")
					},
					accessory: {
						Image(named: .circleSelected)
							.foregroundColor(.passboltPrimaryBlue)
					}
				)

				CommonListResourceView(
					name: "Resource",
					username: "username",
					contentAction: {
						print("contentAction")
					},
					accessory: {
						Image(named: .circleUnselected)
					}
				)

				CommonListResourceView(
					name: "Disabled resource",
					username: "username",
					contentAction: {
						print("contentAction")
					},
					accessory: {
						Image(named: .circleUnselected)
					}
				)
				.disabled(true)
			}
		}
	}
}
#endif

