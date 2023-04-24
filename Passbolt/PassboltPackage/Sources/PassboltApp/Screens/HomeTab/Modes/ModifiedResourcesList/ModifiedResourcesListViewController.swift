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

import UICommons
import UIComponents

internal final class ModifiedResourcesListViewController: PlainViewController, UIComponent {

  internal typealias ContentView = ModifiedResourcesListView
  internal typealias Controller = ModifiedResourcesListController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  internal private(set) lazy var contentView: ContentView = .init()
  internal let components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super
      .init(
        cancellables: cancellables
      )
  }

  internal func setupView() {
    setupNavigationBar()
    setupContentView()
  }

  private func setupNavigationBar() {
    let titleView: PlainView = .init()
    mut(titleView) {
      .backgroundColor(.clear)
    }

    let titleImage: ImageView = .init()
    mut(titleImage) {
      .combined(
        .image(
          named: HomePresentationMode.modifiedResourcesList.iconName,
          from: .uiCommons
        ),
        .tintColor(.passboltPrimaryText),
        .widthAnchor(.equalTo, constant: 24),
        .heightAnchor(.equalTo, constant: 24),
        .subview(of: titleView),
        .centerYAnchor(.equalTo, titleView.centerYAnchor),
        .leadingAnchor(.equalTo, titleView.leadingAnchor)
      )
    }

    let titleLabel: Label = .init()
    mut(titleLabel) {
      .combined(
        .text(displayable: HomePresentationMode.modifiedResourcesList.title),
        .font(.inter(ofSize: 16, weight: .semibold)),
        .textColor(.passboltPrimaryText),
        .textAlignment(.center),
        .subview(of: titleView),
        .topAnchor(.equalTo, titleView.topAnchor),
        .bottomAnchor(.equalTo, titleView.bottomAnchor),
        .trailingAnchor(.equalTo, titleView.trailingAnchor),
        .leadingAnchor(.equalTo, titleImage.trailingAnchor, constant: 8)
      )
    }

    self.navigationItem.titleView = titleView
  }

  private func setupContentView() {
    self.cancellables.executeOnMainActor { [weak self] in
      guard let self = self else { return }
      await self.addChild(
        HomeSearchViewController.self,
        in: { [weak self] text in
          self?.controller.setSearchText(text)
        },
        viewSetup: { parentView, childView in
          parentView.setFiltersView(childView)
        }
      )
      await self.addChild(
        ResourcesListViewController.self,
        in: self.controller.resourcesFilterPublisher(),
        viewSetup: { parentView, childView in
          parentView.setResourcesView(childView)
        }
      )
    }
  }
}
