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

public struct FormLongTextFieldView: View {

  private let title: String
  private let prompt: String?
  private let mandatory: Bool
  private let encrypted: Bool?
  private let state: Validated<String>
  private let update: @MainActor (String) -> Void
  @FocusState private var focused: Bool
  @State private var editing: Bool = false

  public init(
    title: DisplayableString = .raw(""),
    prompt: DisplayableString? = nil,
    mandatory: Bool = false,
    encrypted: Bool? = .none,
    state: Validated<String>,
    update: @escaping @MainActor (String) -> Void
  ) {
    self.title = title.string()
    self.prompt = prompt?.string()
    self.mandatory = mandatory
    self.encrypted = encrypted
    self.state = state
    self.update = update
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: 0
    ) {
      if !self.title.isEmpty {
        HStack {
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
          .frame(
            maxWidth: .infinity,
            alignment: .leading
          )

          if let encrypted {
            Image(
              named: encrypted
                ? .lockedLock
                : .unlockedLock
            )
            .resizable(resizingMode: .stretch)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 12)
          }  // else NOP
        }
        .padding(
          top: 4,
          bottom: 6
        )
      }  // else skip

      ZStack {
        SwiftUI.TextEditor(
          text: .init(
            get: { self.state.value },
            set: { (newValue: String) in
              self.update(newValue)
            }
          )
        )
        .fixedSize(
          horizontal: false,
          vertical: true
        )
        .text(
          font: .inter(
            ofSize: 14,
            weight: .regular
          ),
          color: .passboltPrimaryText
        )
        .multilineTextAlignment(.leading)
        .focused(self.$focused)
        .backport.hideScrollContentBackground()
        .frame(minHeight: 34)

        if self.state.value.isEmpty, let prompt {
          Text(prompt)
            .text(
              font: .inter(
                ofSize: 14,
                weight: .regular
              ),
              color: .passboltSecondaryText
            )
            .padding(
              leading: 5,
              trailing: 5
            )
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
        }  // else NOP
      }
      .onChange(of: focused) { (focused: Bool) in
        withAnimation {
          self.editing = focused
        }
      }
      .padding(
        top: 6,
        leading: 8,
        bottom: 6,
        trailing: 8
      )
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
      .onTapGesture {
        self.focused = true
      }
      .accessibilityIdentifier("form.textfield.text")

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

internal struct FormLongFieldView_Previews: PreviewProvider {

  internal static var previews: some View {
    ScrollView {
      VStack(spacing: 8) {
        PreviewInputState { state, update in
          FormLongTextFieldView(
            title: "Some field title",
            prompt: "editedText",
            state: state,
            update: { text in
              update(text)
              Task {
                try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                update(text)
              }
            }
          )
        }

        FormLongTextFieldView(
          title: "Some required",
          prompt: "editedText",
          mandatory: true,
          state: .valid("edited"),
          update: { _ in }
        )

        FormLongTextFieldView(
          title: "Some required",
          prompt: "editedText",
          mandatory: true,
          state: .invalid(
            "invalidText",
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

        FormLongTextFieldView(
          title: "Some accessory",
          encrypted: true,
          state: .invalid(
            "invalidText",
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

        FormLongTextFieldView(
          title: "Some accessory",
          encrypted: false,
          state: .valid(""),
          update: { _ in }
        )

        FormLongTextFieldView(
          prompt: "accessory with no name",
          encrypted: true,
          state: .valid(""),
          update: { _ in }
        )

        FormLongTextFieldView(
          state: .valid(
            "valid value with some long message displayed to see how it goes when message is really long and will start line breaking with even more than two lines"
          ),
          update: { _ in }
        )

        FormLongTextFieldView(
          prompt: "emptyInvalidText",
          state: .invalid(
            "",
            error:
              InvalidValue
              .empty(
                value: "",
                displayable: "empty"
              )
          ),
          update: { _ in }
        )

        FormLongTextFieldView(
          state: .invalid(
            "invalidText",
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

        FormLongTextFieldView(
          state: .invalid(
            "invalidLongText",
            error:
              InvalidValue
              .error(
                validationRule: "PREVIEW",
                value: "VALUE",
                displayable:
                  "invalid value with some long message displayed to see how it goes when message is really long and will start line breaking with even more than two lines"
              )
          ),
          update: { _ in }
        )
      }
      .padding(8)
    }
  }
}
#endif
