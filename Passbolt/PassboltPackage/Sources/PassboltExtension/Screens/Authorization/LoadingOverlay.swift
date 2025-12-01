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
import UICommons
import UIKit

internal struct LoadingOverlay: View {

  private let loadingMessage: DisplayableString
  private let longLoadingMessage: DisplayableString
  private let longLoadingDelay: TimeInterval
  @State private var showLongLoadingMessage: Bool = false

  internal init(
    loadingMessage: DisplayableString,
    longLoadingMessage: DisplayableString,
    longLoadingDelay: TimeInterval
  ) {
    self.loadingMessage = loadingMessage
    self.longLoadingMessage = longLoadingMessage
    self.longLoadingDelay = longLoadingDelay
  }

  internal var body: some View {
    HStack {
      Spacer()
      VStack {
        Spacer()
        VStack {
          ActivityIndicator(style: .medium)
            .foregroundStyle(Color.passboltPrimaryButtonText)
            .padding(.vertical, 16)
          Text(displayable: showLongLoadingMessage ? longLoadingMessage : loadingMessage)
            .font(.inter(ofSize: 12, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.passboltPrimaryText)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.passboltBackground)
        }

        Spacer()
      }
      Spacer()
    }
    .backgroundColor(.passboltBackgroundOverlay)
    .task {
      Task {
        try await Task.sleep(nanoseconds: UInt64(longLoadingDelay * 1_000_000_000))
        showLongLoadingMessage = true
      }
    }
  }
}

#Preview {
  PlaceholderView()
    .overlay {
      LoadingOverlay(
        loadingMessage: "Loading...",
        longLoadingMessage: "This is taking longer than usual...",
        longLoadingDelay: 5.0
      )
    }
}
