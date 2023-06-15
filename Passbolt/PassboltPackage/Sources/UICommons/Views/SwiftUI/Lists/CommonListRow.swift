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

import SwiftUI

public struct CommonListRow<Content, Accessory>: View
where Content: View, Accessory: View {

  private let content: @MainActor () -> Content
  private let contentAction: (@MainActor () async -> Void)?
  private let accessory: @MainActor () -> Accessory
  private let accessoryAction: (@MainActor () async -> Void)?

  public init(
    contentAction: (@MainActor () async -> Void)? = .none,
    @ViewBuilder content: @escaping @MainActor () -> Content,
    accessoryAction: (@MainActor () async -> Void)? = .none,
    @ViewBuilder accessory: @escaping @MainActor () -> Accessory
  ) {
    self.contentAction = contentAction
    self.content = content
    self.accessoryAction = accessoryAction
    self.accessory = accessory
  }

  public init(
    contentAction: (@MainActor () async -> Void)? = .none,
    @ViewBuilder content: @escaping @MainActor () -> Content
  ) where Accessory == EmptyView {
    self.contentAction = contentAction
    self.content = content
    self.accessoryAction = .none
    self.accessory = EmptyView.init
  }

  public var body: some View {
    if let contentAction, let accessoryAction {
      HStack(spacing: 8) {
        AsyncButton(
          action: contentAction,
          regularLabel: {
            self.content()
              .frame(  // fill space
                maxWidth: .infinity,
                minHeight: 32,
                maxHeight: .infinity,
                alignment: .topLeading
              )
          },
          loadingLabel: {
            HStack(spacing: 8) {
              self.content()
              SwiftUI.ProgressView()
                .progressViewStyle(.circular)
                .tint(.passboltPrimaryText)
            }
            .frame(  // fill space
              maxWidth: .infinity,
              minHeight: 32,
              maxHeight: .infinity,
              alignment: .topLeading
            )
          }
        )

        AsyncButton(
          action: accessoryAction,
          regularLabel: {
            self.accessory()
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          },
          loadingLabel: {
            SwiftUI.ProgressView()
              .progressViewStyle(.circular)
              .tint(.passboltPrimaryText)
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          }
        )
      }
    }
    else if let contentAction {
      AsyncButton(
        action: contentAction,
        regularLabel: {
          HStack(spacing: 8) {
            self.content()
              .frame(  // fill space
                maxWidth: .infinity,
                minHeight: 32,
                maxHeight: .infinity,
                alignment: .topLeading
              )

            self.accessory()
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          }
        },
        loadingLabel: {
          HStack(spacing: 8) {
            self.content()
              .frame(  // fill space
                maxWidth: .infinity,
                minHeight: 32,
                maxHeight: .infinity,
                alignment: .topLeading
              )
						
						SwiftUI.ProgressView()
							.progressViewStyle(.circular)
							.tint(.passboltPrimaryText)

            self.accessory()
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          }
        }
      )
    }
    else if let accessoryAction {
      HStack(spacing: 8) {
        self.content()
          .frame(  // fill space
            maxWidth: .infinity,
            minHeight: 32,
            maxHeight: .infinity,
            alignment: .topLeading
          )

        AsyncButton(
          action: accessoryAction,
          regularLabel: {
            self.accessory()
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          },
          loadingLabel: {
            SwiftUI.ProgressView()
              .progressViewStyle(.circular)
              .tint(.passboltPrimaryText)
              .frame(  // minimal for interaction
                minWidth: 32,
                minHeight: 32
              )
          }
        )
      }
    }
    else {
      HStack(spacing: 8) {
        self.content()
          .frame(  // fill space
            maxWidth: .infinity,
            minHeight: 32,
            maxHeight: .infinity,
            alignment: .topLeading
          )
        self.accessory()
          .frame(  // minimal for interaction
            minWidth: 32,
            minHeight: 32
          )
      }
    }
  }
}
