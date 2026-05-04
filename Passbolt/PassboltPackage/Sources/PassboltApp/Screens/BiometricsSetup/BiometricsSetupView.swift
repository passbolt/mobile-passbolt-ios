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

internal struct BiometricsSetupView: ControlledView {

  internal let controller: BiometricsSetupViewController
  @StateObject private var sheetNavigationState: NavigationState = NavigationState()

  internal init(controller: BiometricsSetupViewController) {
    self.controller = controller
  }

  internal var body: some View {
    NavigationContainer(navigationState: sheetNavigationState) {
      WithViewState(self.controller.viewState) { state in
        InfoView(
          icon: state.icon,
          title: state.title,
          message: state.message,
          primaryButtonTitle: state.primaryButtonTitle,
          primaryButtonAction: self.controller.primaryButtonTapped,
          secondaryButtonTitle: "biometrics.info.later.button",
          secondaryButtonAction: self.controller.skipSetup
        )
      }
    }
    .onAppear {
      self.controller.setSheetNavigationState(self.sheetNavigationState)
    }
  }
}

#if DEBUG

#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        BiometricsSetupView.self,
        with: ()
      )
    }
}
#endif

private struct InfoView: View {

  private let icon: ImageNameConstant
  private let title: DisplayableString
  private let message: DisplayableString?
  private let primaryButtonTitle: DisplayableString
  private let primaryButtonAction: () async -> Void
  private let secondaryButtonTitle: DisplayableString?
  private let secondaryButtonAction: (@Sendable () async -> Void)?

  fileprivate init(
    icon: ImageNameConstant,
    title: DisplayableString,
    message: DisplayableString?,
    primaryButtonTitle: DisplayableString,
    primaryButtonAction: @escaping () async -> Void,
    secondaryButtonTitle: DisplayableString?,
    secondaryButtonAction: (() async -> Void)?
  ) {
    self.icon = icon
    self.title = title
    self.message = message
    self.primaryButtonTitle = primaryButtonTitle
    self.primaryButtonAction = primaryButtonAction
    self.secondaryButtonTitle = secondaryButtonTitle
    self.secondaryButtonAction = secondaryButtonAction
  }

  fileprivate var body: some View {
    VStack(spacing: 0) {
      GeometryReader { reader in
        VStack(spacing: 0) {
          Image(named: icon)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: reader.size.width * 0.6)
            .frame(maxWidth: .infinity)

          Text(displayable: title)
            .titleStyle()
            .padding(.top, 32)

          if let message {
            Text(displayable: message)
              .infoStyle()
              .padding(.top, 16)
          }

          Spacer()
        }
      }
      VStack(spacing: 8) {
        PrimaryButton(
          title: primaryButtonTitle,
          action: primaryButtonAction
        )
        if let secondaryButtonTitle, let secondaryButtonAction {
          SecondaryButton(
            title: secondaryButtonTitle,
            action: { await secondaryButtonAction() }
          )
        }
      }
    }
    .padding(.top, 64)
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
    .navigationBarBackButtonHidden()
  }
}
