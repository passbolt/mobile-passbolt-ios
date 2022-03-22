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
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: ContentView = .init()
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

  func setupView() {
    contentView
      .pullToRefreshPublisher
      .map { [unowned self] () -> AnyPublisher<Void, Never> in
        self.controller
          .refreshResources()
          .receive(on: RunLoop.main)
          .handleEnd { [weak self] _ in
            self?.contentView.finishDataRefresh()
          }
          .handleErrors(
            (
              [.canceled],
              handler: { _ in true /* NOP */ }
            ),
            defaultHandler: { [weak self] error in
              if let displayable: DisplayableString = error.displayableString {
                self?.presentErrorSnackbar(displayable)
              }
              else {
                self?.presentErrorSnackbar()
              }
            }
          )
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

    // Initially refresh resources (ignoring errors)
    self.controller
      .refreshResources()
      .receive(on: RunLoop.main)
      .handleEvents(
        receiveSubscription: { [weak self] _ in
          self?.contentView.startDataRefresh()
        }
      )
      .sink(
        receiveCompletion: { [weak self] completion in
          self?.contentView.finishDataRefresh()
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: self.cancellables)

    controller.resourceDetailsPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] resourceId in
        self?.push(
          ResourceDetailsViewController.self,
          in: resourceId
        )
      }
      .store(in: cancellables)

    controller.resourceMenuPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] resourceID in
        guard let self = self
        else { return }

        self.presentSheetMenu(
          ResourceMenuViewController.self,
          in: (
            resourceID: resourceID,
            showEdit: self.controller.presentResourceEdit,
            showDeleteAlert: self.controller.presentDeleteResourceAlert
          )
        )
      }
      .store(in: cancellables)

    controller
      .resourceCreatePresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        self?.push(
          ResourceEditViewController.self,
          in: (
            .new(in: nil),
            completion: { _ in
              DispatchQueue.main.async {
                self?.presentInfoSnackbar(
                  .localized(
                    key: "resource.form.new.password.created"
                  ),
                  presentationMode: .global
                )
              }
            }
          )
        )
      }
      .store(in: cancellables)

    controller
      .resourceEditPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [unowned self] resourceID in
        self.dismiss(SheetMenuViewController<ResourceMenuViewController>.self) {
          self.push(
            ResourceEditViewController.self,
            in: (
              .existing(resourceID),
              completion: { [weak self] _ in
                DispatchQueue.main.async {
                  self?.presentInfoSnackbar(
                    .localized(key: "resource.menu.action.edited"),
                    presentationMode: .global
                  )
                }
              }
            )
          )
        }
      }
      .store(in: cancellables)

    controller
      .resourceDeleteAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [unowned self] resourceID in
        self.dismiss(SheetMenuViewController<ResourceMenuViewController>.self) {
          self.present(
            ResourceDeleteAlert.self,
            in: { [unowned self] in
              self.controller.resourceDeletionPublisher(resourceID)
                .receive(on: RunLoop.main)
                .handleStart { [weak self] in
                  self?.present(
                    overlay: LoaderOverlayView(
                      longLoadingMessage: (
                        message: .localized(
                          key: .loadingLong
                        ),
                        delay: 5
                      )
                    )
                  )
                }
                .handleErrors(
                  (
                    [.canceled],
                    handler: { _ in true /* NOP */ }
                  ),
                  defaultHandler: { [weak self] error in
                    if let displayable: DisplayableString = error.displayableString {
                      self?.presentErrorSnackbar(displayable)
                    }
                    else {
                      self?.presentErrorSnackbar()
                    }
                  }
                )
                .handleEnd { [weak self] ending in
                  self?.dismissOverlay()

                  guard case .finished = ending
                  else { return }

                  self?.presentInfoSnackbar(
                    .localized("resource.menu.action.deleted"),
                    with: [
                      NSLocalizedString("resource.menu.item.password", bundle: .localization, comment: "")
                    ]
                  )
                }
                .sinkDrop()
                .store(in: cancellables)
            }
          )
        }
      }
      .store(in: cancellables)
  }
}
