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

extension String: FormPickerFieldValue {

  public var id: Self { self }
  public var fromPickerFieldLabel: String { self }
}

public struct FormPickerFieldView<Value>: View
where Value: FormPickerFieldValue {

  private let title: String
  private let mandatory: Bool
  private let prompt: String
  private let values: Array<Value>
  private let state: Validated<String>
  private let update: @MainActor (Value) -> Void
  // FIXME: editing/focus state is not properly changing due to lack of  functions for determining if SwiftUI.Menu appears of disappears, `.onAppear` is called once and only on menu disappear...
  @FocusState private var focused: Bool
  @State private var editing: Bool = false

  public init(
    title: DisplayableString,
    prompt: DisplayableString = "generic.picker.select.placeholder",
    mandatory: Bool = false,
    values: Array<Value>,
    state: Validated<Value>,
    update: @escaping @MainActor (Value) -> Void
  ) {
    self.title = title.string()
    self.prompt = prompt.string()
    self.mandatory = mandatory
    self.values = values
    self.state = state.map(\.fromPickerFieldLabel)
    self.update = update
  }

  public init(
    title: DisplayableString,
    prompt: DisplayableString = "generic.picker.select.placeholder",
    mandatory: Bool = false,
    values: Array<Value>,
    state: Validated<Value?>,
    update: @escaping @MainActor (Value) -> Void
  ) {
    self.title = title.string()
    self.prompt = prompt.string()
    self.mandatory = mandatory
    self.values = values
    self.state = state.map { $0?.fromPickerFieldLabel ?? "" }
    self.update = update
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: 0
    ) {
      if !self.title.isEmpty {
        Group {
          Text(self.title)
            + Text(self.mandatory ? " *" : "")
            .foregroundColor(Color.passboltSecondaryRed)
        }
        .text(
          font: .inter(
            ofSize: 12,
            weight: .medium
          ),
          color: self.state.isValid
            ? Color.passboltPrimaryText
            : Color.passboltSecondaryRed
        )
        .padding(
          top: 4,
          bottom: 6
        )
      }  // else skip

      SwiftUI.Menu(
        content: {
          ForEach(self.values) { (value: Value) in
            Button(
              action: {
                self.update(value)
              },
              label: {
                Text(value.fromPickerFieldLabel)
              }
            )
          }
        },
        label: {
          HStack {
            if self.state.value.isEmpty {
              Text(self.prompt)
                .foregroundColor(.passboltSecondaryText)
            }
            else {
              Text(self.state.value)
                .foregroundColor(.passboltPrimaryText)
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
          .frame(height: 20)
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
              : self.state.isValid
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

      if let message: String = self.state.displayableErrorMessage?.string() {
        Text(message)
          .text(
            .leading,
            font: .inter(
              ofSize: 12,
              weight: .regular
            ),
            color: .passboltSecondaryRed
          )
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )
          .padding(top: 4)
          .accessibilityIdentifier("form.field.error")
      }  // else NOP
    }
    .frame(maxWidth: .infinity)
    .animation(
      .easeIn,
      value: self.state.displayableErrorMessage
    )
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
        prompt: "edited",
        mandatory: false,
        values: [.one, .two, .three],
        state: .valid(.one),
        update: { _ in }
      )

      FormPickerFieldView<MockOptions>(
        title: "Some mandatory field title",
        prompt: "edited",
        mandatory: true,
        values: [.one, .two, .three],
        state: .valid(.one),
        update: { _ in }
      )

      FormPickerFieldView<MockOptions>(
        title: "Some invalid field title",
        prompt: "edited",
        mandatory: true,
        values: [.one, .two, .three, .superlonggtextvaluetoseeifpickerarrowswillmoveanywhere],
        state: .invalid(
          .superlonggtextvaluetoseeifpickerarrowswillmoveanywhere,
          error:
            InvalidValue
            .error(
              validationRule: "PREVIEW",
              value: "VALUE",
              displayable: "invalid value"
            )
        ),
        update: { _ in }
      )

      FormPickerFieldView<MockOptions>(
        title: "Some empty field title",
        prompt: "Not selected value",
        mandatory: false,
        values: [.one, .two, .three],
        state: .valid(.none),
        update: { _ in }
      )

      FormPickerFieldView<MockOptions>(
        title: "Some empty invalid field title",
        prompt: "Not selected value",
        mandatory: true,
        values: [.one, .two, .three],
        state: .invalid(
          .superlonggtextvaluetoseeifpickerarrowswillmoveanywhere,
          error:
            InvalidValue
            .error(
              validationRule: "PREVIEW",
              value: "VALUE",
              displayable: "invalid value"
            )
        ),
        update: { _ in }
      )
    }
    .padding(8)
  }
}
#endif
