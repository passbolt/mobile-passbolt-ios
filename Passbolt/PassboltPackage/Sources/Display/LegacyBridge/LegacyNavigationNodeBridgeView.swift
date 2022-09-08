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
import UIComponents
import UIKit

@available(*, deprecated, message: "Please switch to `NavigationTree`")
internal struct LegacyNavigationNodeBridgeView<Component>: UIViewControllerRepresentable
where Component: UIComponent {

  @State internal private(set) var component: Component
  internal let title: String
  internal let rightBarButton: UIBarButtonItem?

  @MainActor internal init(
    features: FeatureFactory,
    controller: Component.Controller,
    cancellables: Cancellables
  ) {
    let component: Component = .instance(
      using: controller,
      with: .init(features: features),
      cancellables: cancellables
    )
    self.component = component
    self.title = component.title ?? ""
    self.rightBarButton = component.navigationItem.rightBarButtonItem
  }

  internal func makeUIViewController(
    context: Context
  ) -> Component {
    self.component
  }

  internal func updateUIViewController(
    _ uiViewController: Component,
    context: Context
  ) {
    uiViewController.view.setNeedsLayout()
  }

  @ViewBuilder internal var trailingBarButton: some View {
    if let button: UIBarButtonItem = self.rightBarButton {
      Button(
        action: {
          _ = button.target?
            .perform(button.action, with: nil)
        },
        label: {
          if let image: UIImage = button.image {
            Image(uiImage: image)
          }
          else {
            Text(button.title ?? "")
          }
        }
      )
    }
    else {
      EmptyView()
    }
  }
}
