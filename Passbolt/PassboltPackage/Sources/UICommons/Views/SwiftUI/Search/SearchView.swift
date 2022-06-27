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

@MainActor
public struct SearchView<LeftAccessoryView, RightAccessoryView>: View
where LeftAccessoryView: View, RightAccessoryView: View {

  @ObservedObject private var text: ObservableValue<String>
  @FocusState private var editing: Bool
  private let prompt: DisplayableString?
  private let leftAccessory: () -> LeftAccessoryView
  private let rightAccessory: () -> RightAccessoryView

  public init(
    prompt: DisplayableString? = nil,
    text: ObservableValue<String>,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.text = text
    self.prompt = prompt
    self.leftAccessory = leftAccessory
    self.rightAccessory = rightAccessory
  }

  public var body: some View {
    HStack(spacing: 0) {
      if self.editing {
        defaultSearchImage()
          .padding(
            top: 8,
            bottom: 8
          )
          .frame(maxWidth: 48, maxHeight: 48)
      }
      else {
        leftAccessory()
          .aspectRatio(1, contentMode: .fit)
          .padding(
            top: 8,
            bottom: 8
          )
          .frame(maxWidth: 48, maxHeight: 48)
      }

      if let prompt: DisplayableString = self.prompt {
        SwiftUI.TextField(
          "",  // Empty, we don't use this label at all
          text: self.$text.value,
          onEditingChanged: { changed in
            self.editing = changed
          },
          onCommit: {
            self.editing = false
          }
        )
        .focused(self.$editing)
        .contentShape(Rectangle())
        .padding(
          top: 8,
          bottom: 8
        )
        .frame(maxWidth: .infinity, maxHeight: 48)
        .overlay(
          (!self.editing && self.text.value.isEmpty)
            ? AnyView(
              Text(displayable: prompt)
                .foregroundColor(.passboltSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: 20, alignment: .leading)
                .allowsHitTesting(false)
            )
            : AnyView(EmptyView())

        )
      }
      else {
        SwiftUI.TextField(
          "",  // Empty, we don't use this label at all
          text: self.$text.value,
          onEditingChanged: { changed in
            self.editing = changed
          },
          onCommit: {
            self.editing = false
          }
        )
        .contentShape(Rectangle())
        .padding(
          top: 8,
          bottom: 8
        )
        .frame(maxWidth: .infinity, maxHeight: 48)
      }

      if !self.editing, self.text.value.isEmpty {
        rightAccessory()
          .padding(
            top: 8,
            bottom: 8
          )
          .frame(maxWidth: 48, maxHeight: 48)
      }
      else {
        Button(
          action: {
            if self.text.value.isEmpty {
              self.editing = false
            }
            else {
              self.text.value = ""
            }
          },
          label: {
            ImageWithPadding(
              12,
              named: .close
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 48, maxHeight: 48)
          }
        )
      }
    }
    .font(.inter(ofSize: 14, weight: .regular))
    .foregroundColor(.passboltPrimaryText)
    .frame(height: 48)
    .backgroundColor(.passboltBackgroundAlternative)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          self.editing
            ? Color.passboltPrimaryBlue
            : Color.passboltDivider,
          lineWidth: 1
        )
        .allowsHitTesting(false)
    )
  }
}

extension SearchView where LeftAccessoryView == ImageWithPadding {

  public init(
    prompt: DisplayableString? = nil,
    text: ObservableValue<String>,
    @ViewBuilder rightAccessory: @escaping () -> RightAccessoryView
  ) {
    self.init(
      prompt: prompt,
      text: text,
      leftAccessory: defaultSearchImage,
      rightAccessory: rightAccessory
    )
  }
}

extension SearchView where RightAccessoryView == EmptyView {

  public init(
    prompt: DisplayableString? = nil,
    text: ObservableValue<String>,
    @ViewBuilder leftAccessory: @escaping () -> LeftAccessoryView
  ) {
    self.init(
      prompt: prompt,
      text: text,
      leftAccessory: leftAccessory,
      rightAccessory: EmptyView.init
    )
  }
}

extension SearchView where LeftAccessoryView == ImageWithPadding, RightAccessoryView == EmptyView {

  public init(
    prompt: DisplayableString? = nil,
    text: ObservableValue<String>
  ) {
    self.init(
      prompt: prompt,
      text: text,
      leftAccessory: defaultSearchImage,
      rightAccessory: EmptyView.init
    )
  }
}

@MainActor
private func defaultSearchImage() -> ImageWithPadding {
  ImageWithPadding(
    4,
    named: .search
  )
}

#if DEBUG

internal struct SearchView_Previews: PreviewProvider {

  internal static var previews: some View {
    SearchView(
      text: .init(
        initial: ""
      ),
      rightAccessory: {
        UserAvatarView(
          imageData: Generator<Data?>
            .randomAvatarImage()
            .next()
        )
        .padding(4)
      }
    )
  }
}
#endif
