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

public protocol FormPickerFieldValue: Identifiable {

	var fromPickerFieldLabel: String { get }
}

public struct FormPickerFieldView<Value>: View
where Value: FormPickerFieldValue {

	private let title: DisplayableString
	private let mandatory: Bool
	private let prompt: DisplayableString?
	private let values: Array<Value>
	@Binding private var selected: Validated<Value?>
	// FIXME: editing/focus state is not properly changing due to lack of  functions for determining if SwiftUI.Menu appears of disappears, `.onAppear` is called once and only on menu disappear...
	@FocusState private var focused: Bool
	@State private var editing: Bool = false

	public init(
		title: DisplayableString,
		mandatory: Bool = false,
		values: Array<Value>,
		selected: Binding<Validated<Value?>>,
		prompt: DisplayableString? = nil
	) {
		self._selected = selected
		self.title = title
		self.mandatory = mandatory
		self.prompt = prompt
		self.values = values
	}

	public init(
		title: DisplayableString,
		mandatory: Bool = false,
		values: Array<Value>,
		selected: Binding<Validated<Value>>,
		prompt: DisplayableString? = nil
	) {
		self._selected = .init(
			get: {
				if let error: TheError = selected.wrappedValue.error {
					return .invalid(
						selected.wrappedValue.value,
						error: error
					)
				}
				else {
					return .valid(selected.wrappedValue.value)
				}
			},
			set: { (newValue: Validated<Optional<Value>>) in
				guard let newValue = newValue.value else { return }
				selected.wrappedValue = .valid(newValue)
			}
		)
		self.title = title
		self.mandatory = mandatory
		self.prompt = prompt
		self.values = values
	}

	public var body: some View {
		VStack(
			alignment: .leading,
			spacing: 0
		) {
			let title: String = self.title.string()

			if !title.isEmpty {
				Group {
					Text(title)
						+ Text(self.mandatory ? " *" : "")
						.foregroundColor(Color.passboltSecondaryRed)
				}
				.text(
					font: .inter(
						ofSize: 12,
						weight: .medium
					),
					color: self.selected.isValid
						? Color.passboltPrimaryText
						: Color.passboltSecondaryRed
				)
				.padding(
					top: 4,
					bottom: 4
				)
			}  // else skip

			SwiftUI.Menu(
				content: {
					ForEach(self.values) { (value: Value) in
						Button(
							action: {
								self.selected = .valid(value)
							},
							label: {
								Text(value.fromPickerFieldLabel)
							}
						)
					}
				},
				label: {
					HStack {
						if let selectedValueLabel: String = self.selected.value?.fromPickerFieldLabel {
							Text(selectedValueLabel)
								.foregroundColor(.passboltPrimaryText)
						}
						else {
							Text(displayable: self.prompt ?? .raw(""))
								.foregroundColor(.passboltSecondaryText)
						}
						Spacer()
						Image(named: .chevronDown)
							.foregroundColor(.passboltPrimaryText)
					}
					.frame(
						maxWidth: .infinity,
						alignment: .leading
					)
					.font(
						.inter(
							ofSize: 14,
							weight: .regular
						)
					)
					.lineLimit(1)
					.multilineTextAlignment(.leading)
					.padding(12)
				}
			)
			.onChange(of: focused) { (focused: Bool) in
				withAnimation {
					self.editing = focused
				}
			}
			.overlay(
				RoundedRectangle(cornerRadius: 4)
					.stroke(
						self.editing
							? Color.passboltPrimaryBlue
							: self.selected.isValid
								? Color.passboltDivider
								: Color.passboltSecondaryRed,
						lineWidth: 1
					)
					.allowsHitTesting(false)
					.transition(.opacity)
			)
			.padding(1)  // border size
			.backgroundColor(.passboltBackgroundAlternative)
			.cornerRadius(4, corners: .allCorners)
			.accessibilityIdentifier("form.picker.field")

			if let errorMessage: DisplayableString = self.selected.displayableErrorMessage {
				Text(displayable: errorMessage)
					.multilineTextAlignment(.leading)
					.text(
						font: .inter(
							ofSize: 12,
							weight: .regular
						),
						color: .passboltSecondaryRed
					)
					.padding(
						top: 4,
						bottom: 4
					)
					.accessibilityIdentifier("form.picker.error")
			}  // else no view
		}
		.frame(maxWidth: .infinity)
	}
}

#if DEBUG

internal struct FormPickerFieldView_Previews: PreviewProvider {

	private enum MockOptions: String, FormPickerFieldValue {
		var id: Self.RawValue { self.rawValue }

		case one
		case two
		case three
		case superlonggtextvaluetoseeifpickerarrowswillmoveanywhere

		var fromPickerFieldLabel: String {
			self.rawValue
		}
	}

	internal static var previews: some View {
		VStack(spacing: 8) {
			FormPickerFieldView<MockOptions>(
				title: "Some field title",
				mandatory: false,
				values: [.one, .two, .three],
				selected: .constant(.valid(.one)),
				prompt: "edited"
			)

			FormPickerFieldView<MockOptions>(
				title: "Some mandatory field title",
				mandatory: true,
				values: [.one, .two, .three],
				selected: .constant(.valid(.one)),
				prompt: "edited"
			)

			FormPickerFieldView<MockOptions>(
				title: "Some invalid field title",
				mandatory: true,
				values: [.one, .two, .three, .superlonggtextvaluetoseeifpickerarrowswillmoveanywhere],
				selected: .constant(
					.invalid(
						.superlonggtextvaluetoseeifpickerarrowswillmoveanywhere,
						error: InvalidValue
							.error(
								validationRule: "PREVIEW",
								value: "VALUE",
								displayable: "invalid value"
							)
					)
				),
				prompt: "edited"
			)

			FormPickerFieldView<MockOptions>(
				title: "Some empty field title",
				mandatory: false,
				values: [.one, .two, .three],
				selected: .constant(.valid(.none)),
				prompt: "Not selected value"
			)

			FormPickerFieldView<MockOptions>(
				title: "Some empty invalid field title",
				mandatory: true,
				values: [.one, .two, .three],
				selected: .constant(
					.invalid(
						.superlonggtextvaluetoseeifpickerarrowswillmoveanywhere,
						error: InvalidValue
							.error(
								validationRule: "PREVIEW",
								value: "VALUE",
								displayable: "invalid value"
							)
					)
				),
				prompt: "Not selected value"
			)
		}
		.padding(8)
	}
}
#endif
