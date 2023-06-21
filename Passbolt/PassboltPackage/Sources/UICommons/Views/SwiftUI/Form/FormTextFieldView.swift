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

public struct FormTextFieldView<Accessory>: View
where Accessory: View {

  private let title: String
  private let prompt: String?
  private let mandatory: Bool
  private let state: Validated<String>
  private let update: @MainActor (String) -> Void
  private let accessory: () -> Accessory
  @FocusState private var focused: Bool
  @State private var editing: Bool = false

  public init(
    title: DisplayableString = .raw(""),
    prompt: DisplayableString? = nil,
    mandatory: Bool = false,
    state: Validated<String>,
    update: @escaping @MainActor (String) -> Void
  ) where Accessory == EmptyView {
    self.title = title.string()
    self.prompt = prompt?.string()
    self.mandatory = mandatory
    self.state = state
    self.update = update
    self.accessory = EmptyView.init
  }

  public init(
    title: DisplayableString = .raw(""),
    prompt: DisplayableString? = nil,
    mandatory: Bool = false,
    state: Validated<String>,
    update: @escaping @MainActor (String) -> Void,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    self.title = title.string()
    self.prompt = prompt?.string()
    self.mandatory = mandatory
    self.state = state
    self.update = update
    self.accessory = accessory
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

      HStack {
        SwiftUI.TextField(
          self.title,
          text: .init(
            get: { self.state.value },
            set: { (newValue: String) in
              self.update(newValue)
            }
          ),
          prompt: self.prompt
            .map {
              Text($0)
                .text(
                  font: .inter(
                    ofSize: 14,
                    weight: .regular
                  ),
                  color: .passboltSecondaryText
                )
            }
            ?? Text("")
        )
        .text(
          font: .inter(
            ofSize: 14,
            weight: .regular
          ),
          color: .passboltPrimaryText
        )
        .autocorrectionDisabled()
        .autocapitalization(.none)
        .multilineTextAlignment(.leading)
        .focused(self.$focused)
        .onChange(of: focused) { (focused: Bool) in
          withAnimation {
            self.editing = focused
          }
        }
        .frame(height: 20)
        .padding(12)
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
        .frame(minWidth: 65)
        .accessibilityIdentifier("form.textfield.text")

        self.accessory()
      }

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

internal struct FormTextFieldView_Previews: PreviewProvider {

  internal static var previews: some View {
    ScrollView {
      VStack(spacing: 8) {
        PreviewInputState { state, update in
          FormTextFieldView(
            title: "Some field title",
            prompt: "Live to edit in preview!",
            state: state,
            update: update
          )
        }

        FormTextFieldView(
          title: "Some required",
          prompt: "editedText",
          mandatory: true,
          state: .valid("edited"),
          update: { _ in }
        )

        FormTextFieldView(
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

        FormTextFieldView(
          title: "Some accessory",
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
          update: { _ in },
          accessory: {
            Button(
              action: {},
              label: {
                Image(named: .dice)
                  .tint(.passboltPrimaryText)
                  .padding(12)
                  .backgroundColor(.passboltDivider)
                  .cornerRadius(4)
              }
            )
          }
        )

        FormTextFieldView(
          title: "Some accessory",
          state: .valid(""),
          update: { _ in },
          accessory: {
            Button(
              action: {},
              label: {
                Image(named: .dice)
                  .tint(.passboltPrimaryText)
                  .padding(12)
                  .backgroundColor(.passboltDivider)
                  .cornerRadius(4)
              }
            )
          }
        )

        FormTextFieldView(
          prompt: "accessory with no name",
          state: .valid(""),
          update: { _ in },
          accessory: {
            Button(
              action: {},
              label: {
                Image(named: .dice)
                  .tint(.passboltPrimaryText)
                  .padding(12)
                  .backgroundColor(.passboltDivider)
                  .cornerRadius(4)
              }
            )
          }
        )

        FormTextFieldView(
          state: .valid("validText"),
          update: { _ in }
        )

        FormTextFieldView(
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

        FormTextFieldView(
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

        FormTextFieldView(
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
