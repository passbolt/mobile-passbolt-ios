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
import UICommons

internal struct ResourceIconEditView: ControlledView {

  internal let controller: ResourceIconEditViewController

  @FocusState private var focusState

  internal init(
    controller: ResourceIconEditViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.content
      .frame(maxHeight: .infinity)
      .overlay(alignment: .bottom) {
        VStack {
          Spacer()
          VStack(spacing: 0) {
            PrimaryButton(
              title: "generic.apply",
              action: {
                await self.controller.apply()
              }
            )
          }
          .padding(16)
          .background(Color.passboltBackground)
        }
        .ignoresSafeArea(.keyboard)
      }
      .navigationTitle(
        displayable: self.controller.editsExisting
          ? "resource.edit.title"
          : "resource.edit.create.title"
      )
      .backgroundColor(.passboltBackground)
      .navigationBarBackButtonHidden()
      .toolbar {  // replace back button
        ToolbarItemGroup(placement: .navigationBarLeading) {
          BackButton(
            action: {
              await self.controller.discardForm()
            }
          )
        }
      }
  }

  private var content: some View {
    CommonList {
      CommonListSection {
        VStack(alignment: .leading, spacing: 8) {
          Text(displayable: "resource.edit.icon.title")
            .font(.inter(ofSize: 16, weight: .bold))
            .padding(.vertical, 20)
            .padding(.top, 20)
            .foregroundColor(.primary)

          VStack(alignment: .leading, spacing: 0) {
            Text(displayable: "resource.edit.icon.color.select.title")
              .font(.inter(ofSize: 12, weight: .bold))
              .padding(.vertical, 20)
              .foregroundColor(.primary)

            VStack {
              CommonListRow(
                content: {
                  HStack(alignment: .center, spacing: 12) {
                    Text(displayable: "resource.edit.icon.color.default.title")
                      .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .leading
                      )
                      .multilineTextAlignment(.leading)
                      .padding(.leading, 16)
                  }
                  .font(
                    .inter(
                      ofSize: 14,
                      weight: .semibold
                    )
                  )
                },
                accessory: {
                  with(\.defaultColorSelected) { (defaultColorSelected: Bool) in
                    AsyncToggle(
                      state: defaultColorSelected,
                      toggle: { (newValue: Bool) in
                        guard newValue else { return }
                        self.controller.update(color: nil)
                      }
                    )
                    .accessibilityIdentifier("resource.edit.icon.color.default.toggle")
                  }
                }
              )
              .padding(.bottom, 16)
              colorPicker
              Spacer()
            }
            .padding(.vertical, 16)

            VStack {
              CommonListRow(
                content: {
                  HStack(alignment: .center, spacing: 12) {
                    Text(displayable: "resource.edit.icon.default.title")
                      .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .leading
                      )
                      .multilineTextAlignment(.leading)
                      .padding(.leading, 16)
                  }
                  .font(
                    .inter(
                      ofSize: 14,
                      weight: .semibold
                    )
                  )
                },
                accessory: {
                  with(\.defautlIconSelected) { (defaultIconSelected: Bool) in
                    AsyncToggle(
                      state: defaultIconSelected,
                      toggle: { (newValue: Bool) in
                        guard newValue else { return }
                        self.controller.update(icon: nil)
                      }
                    )
                    .accessibilityIdentifier("resource.edit.icon.default.color.toggle")
                  }
                }
              )
              .padding(.bottom, 16)
              iconPicker

              Spacer()
            }
            .padding(.vertical, 16)
          }
          .padding(.bottom, 96)
        }
      }
      .backgroundColor(.passboltBackground)
    }
  }

  @ViewBuilder private var iconPicker: some View {
    with(\.availableIcons) { (availableIcons: [ResourceIcon.IconIdentifier]) in
      LazyVGrid(
        columns: [.init(.adaptive(minimum: 40, maximum: 40))],
        spacing: 8
      ) {
        ForEach(availableIcons, id: \.self) { (icon: ResourceIcon.IconIdentifier) in
          ZStack {
            with(\.selectedIcon) { (selectedIcon: ResourceIcon.IconIdentifier?) in
              Circle()
                .fill(Color.passboltIcon)
                .frame(width: 40, height: 40)
                .overlay(
                  RoundedRectangle(cornerRadius: 20)
                    .stroke(
                      selectedIcon == icon
                        ? Color.passboltPrimaryBlue
                        : Color.clear,
                      lineWidth: 4
                    )
                )
            }
            KeepassIcons.icon(for: icon)?
              .resizable()
              .renderingMode(.template)
              .aspectRatio(contentMode: .fit)
              .foregroundColor(.white)
          }
          .onTapGesture {
            self.controller.update(icon: icon)
          }
        }
      }
    }
  }

  @ViewBuilder private var colorPicker: some View {
    with(\.availableColors) { (availableColors: [Color.Hex]) in
      LazyVGrid(
        columns: [.init(.adaptive(minimum: 40, maximum: 50))],
        spacing: 8
      ) {
        ForEach(availableColors, id: \.self) { (color: Color.Hex) in
          ZStack {
            Circle()
              .fill(Color(hex: color) ?? .black)
              .frame(width: 40, height: 40)
              .overlay(
                Color.isFullyTransparent(hex: color)
                  ? RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                  : nil
              )
            with(\.selectedColorHex) { (selectedColor: Color.Hex?) in
              if color == selectedColor {
                Image(named: .checkmark)
                  .resizable()
                  .renderingMode(.template)
                  .aspectRatio(contentMode: .fit)
                  .foregroundColor(Color.luminance(for: color) ?? .black)
                  .padding(12)
              }
            }
          }
          .onTapGesture {
            self.controller.update(color: color)
          }
        }
      }
    }
  }
}
