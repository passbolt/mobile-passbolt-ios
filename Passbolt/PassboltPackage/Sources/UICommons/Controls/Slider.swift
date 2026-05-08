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

public struct Slider: View {

  @Binding private var value: Int
  private let title: DisplayableString
  private let min: Int
  private let max: Int
  private let onCommit: (() -> Void)?
  @State private var inputText: String
  @FocusState private var fieldFocused: Bool

  private var range: ClosedRange<Double> {
    Double(min) ... Double(max)
  }

  public init(
    _ title: DisplayableString,
    value: Binding<Int>,
    min: Int,
    max: Int,
    onCommit: (() -> Void)? = nil
  ) {
    self.title = title
    self._value = value
    self.min = min
    self.max = max
    self.onCommit = onCommit
    self._inputText = State(initialValue: String(value.wrappedValue))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(displayable: title)
        .text(
          font: .inter(ofSize: 12, weight: .semibold),
          color: .passboltPrimaryText
        )
      HStack(spacing: 8) {
        SwiftUI.Slider(
          value: .init(
            get: { Double(value) },
            set: { (newValue: Double) in
              if self.fieldFocused {
                self.fieldFocused = false
              }
              value = Int(newValue)
            }
          ),
          in: range,
          step: 1,
          onEditingChanged: { (editing: Bool) in
            if !editing {
              self.onCommit?()
            }
          }
        )
        .tint(Color.passboltPrimaryBlue)
        TextField(
          text: self.$inputText,
          label: {
            EmptyView()
          }
        )
        .focused(self.$fieldFocused)
        .onChange(of: self.inputText) { (newText: String) in
          let filtered: String = newText.filter { ("0" ... "9").contains($0) }
          if filtered != newText {
            self.inputText = filtered
            return
          }
          if let parsed: Int = Int(filtered),
            (min ... max).contains(parsed),
            value != parsed
          {
            value = parsed
          }
        }
        .onChange(of: self.fieldFocused) { (isFocused: Bool) in
          guard !isFocused else { return }
          // On commit (focus loss / Return), require an in-range parse;
          // otherwise revert to the last valid value.
          let inRange: Bool =
            Int(self.inputText)
            .map { (min ... max).contains($0) } ?? false
          if !inRange {
            self.inputText = String(value)
          }
          self.onCommit?()
        }
        .onSubmit {
          let inRange: Bool =
            Int(self.inputText)
            .map { (min ... max).contains($0) } ?? false
          if !inRange {
            self.inputText = String(value)
          }
          self.onCommit?()
        }
        .onChange(of: value) { (newValue: Int) in
          if !self.fieldFocused, Int(self.inputText) != newValue {
            self.inputText = String(newValue)
          }
        }
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .frame(width: 42, height: 32)
        .backgroundColor(Color.passboltBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.passboltDivider, lineWidth: 1)
        }
        .text(
          font: .inter(ofSize: 14, weight: .regular),
          color: .passboltPrimaryText
        )
      }
    }
  }
}
