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

import UIComponents

internal final class ResourceDetailsViewController: PlainViewController, UIComponent {

  internal typealias View = ResourceDetailsView
  internal typealias Controller = ResourceDetailsController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal private(set) lazy var contentView: View = .init()

  internal let components: UIComponentFactory

  private let controller: Controller
  private var resourceDetailsCancellable: AnyCancellable?

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setupView() {
    mut(navigationItem) {
      .rightBarButtonItem(
        Mutation<UIBarButtonItem>.combined(
          .style(.done),
          .image(named: .more, from: .uiCommons),
          .action { [weak self] in
            self?.controller.presentResourceMenu()
          }
        )
        .instantiate()
      )
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    resourceDetailsCancellable = controller.resourceDetailsWithConfigPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] completion in
        guard case .failure = completion
        else { return }

        self?.navigationController?.presentErrorSnackbar()
        self?.pop(if: Self.self)
      } receiveValue: { [weak self] resourceDetailsWithConfig in
        self?.contentView.update(with: resourceDetailsWithConfig)
      }

    controller.resourceMenuPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [unowned self] resourceID in
        self.presentSheet(
          ResourceMenuViewController.self,
          in: (
            resourceID: resourceID,
            showDeleteAlert: self.controller.presentDeleteResourceAlert
          )
        )
      }
      .store(in: cancellables)

    contentView.toggleEncryptedFieldTapPublisher
      .map { [unowned self] field in
        self.controller.toggleDecrypt(field)
          .receive(on: RunLoop.main)
          .handleEvents(receiveOutput: { [weak self] value in
            self?.contentView.applyOn(
              field: field,
              buttonMutation: .combined(.when(
                value != nil,
                then: .image(named: .eyeSlash, from: .uiCommons),
                else: .image(named: .eye, from: .uiCommons)
              )
            ),
              valueTextViewMutation: .when(
                value != nil,
                then: .combined(
                  .text(value ?? ""),
                  .font(.inconsolata(ofSize: 14, weight: .bold))
                ),
                else: .combined(
                  .text(String(repeating: "*", count: 10)),
                  .font(.inter(ofSize: 14, weight: .medium))
                )
              )
            )
          }, receiveCompletion: { [weak self] completion in
            guard case .failure = completion
            else { return }
            self?.present(
              snackbar: Mutation<UICommons.View>
                .snackBarErrorMessage(
                  localized: .genericError,
                  inBundle: .commons
                )
                .instantiate(),
              hideAfter: 2
            )
          })
          .mapToVoid()
          .replaceError(with: Void())
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)


    contentView
      .copyFieldNameTapPublisher
      .map { [unowned self] field in
        self.controller
          .copyFieldValue(field)
          .receive(on: RunLoop.main)
          .handleEvents(receiveOutput: { [weak self] in
            switch field {
            case .uri:
              self?.presentInfoSnackbar(
                localizableKey: "resource.menu.item.field.copied",
                inBundle: .main,
                arguments: [
                  NSLocalizedString("resource.menu.item.url", comment: "")
                ]
              )

            case .password:
              self?.presentInfoSnackbar(
                localizableKey: "resource.menu.item.field.copied",
                inBundle: .main,
                arguments: [
                  NSLocalizedString("resource.menu.item.password", comment: "")
                ]
              )

            case .username:
              self?.presentInfoSnackbar(
                localizableKey: "resource.menu.item.field.copied",
                inBundle: .main,
                arguments: [
                  NSLocalizedString("resource.menu.item.username", comment: "")
                ]
              )

            case .description:
              self?.presentInfoSnackbar(
                localizableKey: "resource.menu.item.field.copied",
                inBundle: .main,
                arguments: [
                  NSLocalizedString("resource.menu.item.description", comment: "")
                ]
              )
            }
          })
          .handleErrors(
            ([.canceled, .authorizationRequired], handler: { _ in true /* NOP */ }),
            defaultHandler: { [weak self] _ in
              self?.presentErrorSnackbar()
            }
          )
          .mapToVoid()
          .replaceError(with: Void())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)

    controller.resourceDeleteAlertPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [unowned self] resourceID in
        self.dismiss(ResourceMenuViewController.self) {
          self.present(
            ResourceDeleteAlert.self,
            in: { [unowned self] in
              self.controller.resourceDeletionPublisher(resourceID)
                .receive(on: RunLoop.main)
                .handleStart { [weak self] in
                  self?.present(overlay: LoaderOverlayView())
                }
                .handleErrors(
                  (
                    [.canceled],
                    handler: { _ in true /* NOP */ }
                  ),
                  defaultHandler: { [weak self] _ in
                    self?.presentErrorSnackbar()
                  }
                )
                .handleEnd { [weak self] ending in
                  resourceDetailsCancellable = nil

                  self?.dismissOverlay()

                  guard case .finished = ending
                  else { return }

                  self?.presentInfoSnackbar(
                    localizableKey: "resource.menu.action.deleted",
                    inBundle: .main,
                    presentationMode: .global,
                    arguments: [
                      NSLocalizedString("resource.menu.item.password", comment: "")
                    ]
                  )

                  self?.pop(if: Self.self)
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
