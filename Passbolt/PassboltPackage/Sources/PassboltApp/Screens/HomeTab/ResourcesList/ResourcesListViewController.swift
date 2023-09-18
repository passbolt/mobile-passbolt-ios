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

import SharedUIComponents
import UICommons
import UIComponents

internal final class ResourcesListViewController: PlainViewController, UIComponent {

  internal typealias ContentView = ResourcesListView
  internal typealias Controller = ResourcesListController

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

  func setupView() {
    self.contentView
      .pullToRefreshPublisher
      .map { [unowned self] () -> AnyPublisher<Void, Never> in
        self.controller
          .refreshResources()
          .receive(on: RunLoop.main)
          .handleEnd { [weak self] _ in
            self?.contentView.finishDataRefresh()
          }
          .handleErrors { [weak self] error in
            switch error {
            case is Cancelled:
              return /* NOP */
            case _:
              self?.presentErrorSnackbar(error.displayableMessage)
            }
          }
          .mapToVoid()
          .replaceError(with: Void())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: self.cancellables)

    self.controller
      .resourcesListPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] resources in
        let items: Array<ResourcesListViewItem>
        if resources.isEmpty {
          items = []
        }
        else {
          items = [.add] + resources.map { .resource($0) }
        }
        self?.contentView.update(data: items)
        self?.contentView.finishDataRefresh()
      }
      .store(in: self.cancellables)

    contentView
      .addTapPublisher
      .sink { [weak self] in
        self?.controller.addResource()
      }
      .store(in: self.cancellables)

    contentView
      .itemTapPublisher
      .sink { [weak self] item in
        self?.controller.presentResourceDetails(item)
      }
      .store(in: self.cancellables)

    contentView
      .itemMenuTapPublisher
      .sink { [weak self] item in
        self?.controller.presentResourceMenu(item)
      }
      .store(in: self.cancellables)

    // load view in loading state
    self.contentView.startDataRefresh()
  }
}
