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

internal final class HomeFilterViewController: PlainViewController, UIComponent {

  internal typealias ContentView = HomeFilterView
  internal typealias Controller = HomeFilterController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: ContentView = .init()
  private lazy var displayButton: ImageButton = .init()
  private lazy var avatarButton: ImageButton = .init()
  private lazy var searchBar: TextSearchView = .init(
    leftAccesoryView: displayButton,
    rightAccesoryView: avatarButton
  )
  internal let components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    setupNavigationView()
    setupResourcesListView()
  }

  private func setupNavigationView() {
    mut(displayButton) {
      .combined(
        .action { [weak self] in
          self?.controller.presentDisplayMenu()
        },
        .image(named: .filter, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(.clear),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }
    mut(avatarButton) {
      .combined(
        .action { [weak self] in
          self?.controller.presentAccountMenu()
        },
        .image(named: .person, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .backgroundColor(dynamic: .background),
        .border(dynamic: .divider),
        .cornerRadius(14, masksToBounds: true),
        .widthAnchor(.equalTo, constant: 28),
        .heightAnchor(.equalTo, constant: 28)
      )
    }

    searchBar
      .textPublisher
      .removeDuplicates()
      .debounce(for: 0.3, scheduler: RunLoop.main)
      .sink { [weak self] text in
        self?.controller.updateSearchText(text)
      }
      .store(in: cancellables)

    controller
      .searchTextPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] text in
        self?.searchBar.setText(text)
      }
      .store(in: cancellables)

    navigationItem.titleView = searchBar

    controller
      .avatarImagePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] imageData in
        guard
          let data: Data = imageData,
          let image: UIImage = .init(data: data)
        else { return }

        self?.avatarButton.image = image
      }
      .store(in: cancellables)

    controller
      .displayMenuPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] currentDisplay, availableDisplays, updateDisplay in
        guard let self = self else { return }
        self.presentSheet(
          ResourceDisplayMenuView.self,
          in: (
            currentDisplay: currentDisplay,
            availableDisplays: availableDisplays,
            updateDisplay: updateDisplay
          )
        )
      }
      .store(in: cancellables)

    controller
      .accountMenuPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] accountWithProfile in
        guard let self = self else { return }
        self.presentSheetMenu(
          AccountMenuViewController.self,
          in: (
            accountWithProfile: accountWithProfile,
            parentComponent: self
          )
        )
      }
      .store(in: cancellables)
  }

  private func setupResourcesListView() {
    addChild(
      ResourcesListViewController.self,
      in: controller.resourcesFilterPublisher(),
      viewSetup: { parentView, childView in
        parentView.setResourcesView(childView)
      }
    )
  }
}
