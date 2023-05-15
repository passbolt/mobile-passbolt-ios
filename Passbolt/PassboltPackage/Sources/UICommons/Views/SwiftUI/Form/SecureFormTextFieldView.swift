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

public struct SecureFormTextFieldView: View {

  private let title: DisplayableString
  private let mandatory: Bool
  private let prompt: DisplayableString?
  @Binding private var text: Validated<String>
  @FocusState private var focused: Bool
  @State private var editing: Bool = false
  @State private var masked: Bool = true

  public init(
    title: DisplayableString = .raw(""),
    mandatory: Bool = false,
    text: Binding<Validated<String>>,
    prompt: DisplayableString? = nil
  ) {
    self._text = text
    self.title = title
    self.mandatory = mandatory
    self.prompt = prompt
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
          color: self.text.isValid
            ? Color.passboltPrimaryText
            : Color.passboltSecondaryRed
        )
        .padding(
          top: 4,
          bottom: 4
        )
        .accessibilityIdentifier("form.textfield.label")
      }  // else skip

      HStack(spacing: 8) {
        self.textField
          .text(
            font: .inter(
              ofSize: 14,
              weight: .regular
            ),
            color: .passboltPrimaryText
          )
          .multilineTextAlignment(.leading)
          .focused(self.$focused)
          .onChange(of: focused) { (focused: Bool) in
            withAnimation {
              self.editing = focused
            }
          }
          .padding(12)
          .accessibilityIdentifier("form.textfield.field")

        Button(
          action: {
            self.masked.toggle()
          },
          label: {
            if self.masked {
              Image(named: .eye)
            }
            else {
              Image(named: .eyeSlash)
            }
          }
        )
        .padding(trailing: 8)
        .accessibilityIdentifier("form.textfield.eye")
      }
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(
            self.editing
              ? Color.passboltPrimaryBlue
              : self.text.isValid
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
      .onTapGesture {
        self.focused = true
      }

      if let errorMessage: DisplayableString = self.text.displayableErrorMessage {
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
          .accessibilityIdentifier("form.textfield.error")
      }  // else no view
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder private var textField: some View {
    if self.masked {
      SwiftUI.SecureField(
        title.string(),
        text: .init(
          get: { self.text.value },
          set: { newValue in
            self.text.value = newValue
          }
        ),
        prompt: self.prompt
          .map {
            Text(displayable: $0)
              .text(
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .passboltSecondaryText
              )
          }
      )
    }
    else {
      SwiftUI.TextField(
        title.string(),
        text: .init(
          get: { self.text.value },
          set: { newValue in
            self.text.value = newValue
          }
        ),
        prompt: self.prompt
          .map {
            Text(displayable: $0)
              .text(
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .passboltSecondaryText
              )
          }
      )
    }
  }
}

#if DEBUG

internal struct SecureFormTextFieldView_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack(spacing: 8) {
      SecureFormTextFieldView(
        title: "Some field title",
        text: .constant(.valid("edited")),
        prompt: "editedText"
      )

      FormTextFieldView(
        title: "Some required",
        mandatory: true,
        text: .constant(.valid("edited")),
        prompt: "editedText"
      )

      FormTextFieldView(
        title: "Some required",
        mandatory: true,
        text: .constant(
          .invalid(
            "invalidText",
            error:
              InvalidValue
              .error(
                validationRule: "PREVIEW",
                value: "VALUE",
                displayable: "invalid value"
              )
          )
        ),
        prompt: "editedText"
      )

      FormTextFieldView(
        text: .constant(.valid("edited")),
        prompt: "editedText"
      )

      FormTextFieldView(
        text: .constant(.valid("")),
        prompt: "emptyText"
      )

      FormTextFieldView(
        text: .constant(.valid("validText"))
      )

      FormTextFieldView(
        text: .constant(
          .invalid(
            "",
            error:
              InvalidValue
              .empty(
                value: "",
                displayable: "empty"
              )
          )
        ),
        prompt: "emptyInvalidText"
      )

      FormTextFieldView(
        text: .constant(
          .invalid(
            "invalidText",
            error:
              InvalidValue
              .error(
                validationRule: "PREVIEW",
                value: "VALUE",
                displayable: "invalid value"
              )
          )
        )
      )

      SecureFormTextFieldView(
        text: .constant(
          .invalid(
            "invalidLongText",
            error:
              InvalidValue
              .error(
                validationRule: "PREVIEW",
                value: "VALUE",
                displayable:
                  "invalid value with some long message displayed to see how it goes when message is really long and will start line breaking with even more than two lines"
              )
          )
        )
      )
    }
    .padding(8)
  }
}
#endif
