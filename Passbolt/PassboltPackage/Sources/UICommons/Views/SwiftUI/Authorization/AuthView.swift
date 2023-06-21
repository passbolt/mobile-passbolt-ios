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

import Localization
import SwiftUI

#warning("To be renamed to AuthorizationView when current one becomes replaced.")
public struct AuthView<SupportActionView>: View
where SupportActionView: View {

  private let label: String
  private let username: String
  private let domain: String
  private let avatarImage: Data?
  private var passphrase: Validated<String>
  private let updatePassphrase: @MainActor (String) -> Void
  private let mainActionLabel: DisplayableString
  private let mainAction: () -> Void
  private let biometricsAvailability: OSBiometryAvailability
  private let biometricsAction: () -> Void
  private let supportActionView: @MainActor () -> SupportActionView

  public init(
    label: String,
    username: String,
    domain: String,
    avatarImage: Data?,
    passphrase: Validated<String>,
    updatePassphrase: @escaping @MainActor (String) -> Void,
    mainActionLabel: DisplayableString,
    mainAction: @escaping () -> Void,
    biometricsAvailability: OSBiometryAvailability,
    biometricsAction: @escaping () -> Void,
    @ViewBuilder supportActionView: @escaping @MainActor () -> SupportActionView
  ) {
    self.label = label
    self.username = username
    self.domain = domain
    self.avatarImage = avatarImage
    self.passphrase = passphrase
    self.updatePassphrase = updatePassphrase
    self.mainActionLabel = mainActionLabel
    self.mainAction = mainAction
    self.biometricsAvailability = biometricsAvailability
    self.biometricsAction = biometricsAction
    self.supportActionView = supportActionView
  }

  public var body: some View {
    VStack(spacing: 16) {
      AvatarView {
        self.avatarImage
          .flatMap(Image.init(data:))?
          .resizable()
          ?? Image(named: .person)
          .resizable()
      }
      .frame(width: 96, height: 96)
      .padding(top: 56)
      .accessibilityIdentifier("authorization.passphrase.avatar")

      Text(self.label)
        .text(
          font: .inter(
            ofSize: 20,
            weight: .semibold
          ),
          color: .passboltPrimaryText
        )

      Text(self.username)
        .text(
          font: .inter(ofSize: 14),
          color: .passboltSecondaryText
        )

      Text(self.domain)
        .text(
          font: .inter(ofSize: 14),
          color: .passboltSecondaryText
        )

      FormSecureTextFieldView(
        title: .localized(
          key: "authorization.passphrase.description.text"
        ),
        prompt: "",
        mandatory: true,
        state: self.passphrase,
        update: self.updatePassphrase
      )
      .padding(top: 16)

      switch self.biometricsAvailability {
      case .unavailable, .unconfigured:
        EmptyView()

      case .faceID:
        Button(
          action: self.biometricsAction,
          label: {
            Image(named: .faceID)
              .resizable()
              .padding(10)
          }
        )
        .frame(width: 56, height: 56)
        .tint(.passboltPrimaryBlue)
        .overlay(
          Circle()
            .stroke(
              Color.passboltDivider,
              lineWidth: 1
            )
        )

      case .touchID:
        Button(
          action: self.biometricsAction,
          label: {
            Image(named: .touchID)
              .resizable()
              .padding(10)
          }
        )
        .frame(width: 56, height: 56)
        .tint(.passboltPrimaryBlue)
        .overlay(
          Circle()
            .stroke(
              Color.passboltDivider,
              lineWidth: 1
            )
        )
      }

      Spacer()

      PrimaryButton(
        title: self.mainActionLabel,
        action: self.mainAction
      )
      .accessibilityIdentifier("transfer.account.export.passphrase.primary.button")

      self.supportActionView()
        .padding(top: -8)
    }
    .padding(16)
  }
}

#if DEBUG

internal struct AuthView_Previews: PreviewProvider {

  internal static var previews: some View {
    PreviewInputState { state, update in
      AuthView(
        label: "AccountLabel",
        username: "user@passbolt.com",
        domain: "https://passbolt.com",
        avatarImage: .none,
        passphrase: state,
        updatePassphrase: update,
        mainActionLabel: "MainAction",
        mainAction: {},
        biometricsAvailability: .faceID,
        biometricsAction: {},
        supportActionView: EmptyView.init
      )
    }
  }
}
#endif
