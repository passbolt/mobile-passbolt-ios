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

import AegithalosCocoa
import Commons
import SwiftUI

@MainActor
public struct AvatarButton: View {

  @State private var currentImage: Image
  private let resolveImage: @Sendable () async -> Data?
  private let action: @MainActor () async -> Void

  public init(
    resolveImage: @escaping @Sendable () async -> Data?,
    action: @escaping @MainActor () async -> Void
  ) {
    self.currentImage = Image(named: .person)
    self.resolveImage = resolveImage
    self.action = action
  }

  public var body: some View {
    AsyncButton(
      action: self.action,
      regularLabel: {
        AvatarView {
          self.currentImage
        }
      },
      loadingLabel: {
        AvatarView {
          self.currentImage
        }
        .overlay {
          ZStack {
            Color.passboltBackground.opacity(0.5)
            SwiftUI.ProgressView()
              .progressViewStyle(.circular)
          }
        }
      }
    )
    .foregroundColor(.passboltPrimaryText)
    .tint(.passboltPrimaryText)
    .backgroundColor(.clear)
    .task {
      if let resolvedImage: Image = await self.resolveImage().flatMap(Image.init(data:)) {
        self.currentImage = resolvedImage
      }  // else keep current
    }
  }
}

#if DEBUG

internal struct AvatarButton_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack {
      AvatarButton(
        resolveImage: { .none },
        action: {
          print("TAP")
          try? await Task.sleep(nanoseconds: 1500 * NSEC_PER_MSEC)
        }
      )
    }
    .padding()
  }
}
#endif
