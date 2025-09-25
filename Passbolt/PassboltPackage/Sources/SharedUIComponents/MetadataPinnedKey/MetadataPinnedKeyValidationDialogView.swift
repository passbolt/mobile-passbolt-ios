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

public struct MetadataPinnedKeyValidationDialogView: ControlledView {

  public let controller: MetadataPinnedKeyValidationDialogViewController

  public init(
    controller: MetadataPinnedKeyValidationDialogViewController
  ) {
    self.controller = controller
  }

  public var body: some View {
    VStack(spacing: 18) {

      title
        .font(.inter(ofSize: 24))
        .fontWeight(.bold)
        .foregroundColor(.primary)
      message
        .font(.inter(ofSize: 14))
        .foregroundColor(.secondary)

      Text(displayable: "metadata.pinned.key.validation.error.disclaimer")
        .font(.inter(ofSize: 14))
        .foregroundColor(.secondary)
      whenUnwrapped(\.formattedFingerprint) { (formattedFingerprint: String) in

        Text(displayable: "metadata.pinned.key.fingerprint")
          .font(.inter(ofSize: 14))
          .foregroundColor(.secondary)

        Text(formattedFingerprint)
          .font(.inconsolata(ofSize: 16))
          .fontWeight(.bold)
          .foregroundColor(.primary)
      }

      Spacer()
    }
    .navigationBarBackButtonHidden()
    .padding(.horizontal, 24)
    .multilineTextAlignment(.center)
    .overlay {
      VStack(spacing: 0) {
        Spacer()
        when(\.canTrust) {
          PrimaryButton(
            title: "metadata.pinned.key.validation.error.trust",
            action: {
              try await controller.trust()
            }
          )
          SecondaryButton(
            title: "generic.cancel",
            action: { await self.controller.dismiss() }
          )
        }
        when(\.unknownReason) {
          PrimaryButton(
            title: "generic.ok",
            action: { await self.controller.dismiss() }
          )
        }
      }
      .padding(.horizontal, 24)
    }
    .padding(.top, 60)
  }

  @ViewBuilder
  private var title: some View {
    when(\.isChanged) {
      Text(displayable: "metadata.pinned.key.validation.error.title")
    }
    when(\.isDeleted) {
      Text(displayable: "metadata.pinned.key.validation.deleted.title")
    }
    when(\.unknownReason) {
      Text(displayable: "metadata.pinned.key.validation.unknown.title")
    }
  }

  @ViewBuilder
  private var message: some View {
    when(\.isChanged) {
      whenUnwrapped(\.userDisplayName) { (userDisplayName: String) in
        Text(displayable: "metadata.pinned.key.validation.error.message", arguments: userDisplayName)
      }
    }
    when(\.isDeleted) {
      Text(displayable: "metadata.pinned.key.validation.deleted.message")
    }
    when(\.unknownReason) {
      Text(displayable: "metadata.pinned.key.validation.unknown.message")
    }
  }
}
