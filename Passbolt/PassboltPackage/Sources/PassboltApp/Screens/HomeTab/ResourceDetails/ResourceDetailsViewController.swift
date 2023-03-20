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
import UIComponents

internal final class ResourceDetailsViewController: PlainViewController, UIComponent {

  internal typealias ContentView = ResourceDetailsView
  internal typealias Controller = ResourceDetailsController

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
  private var resourceDetailsCancellable: AnyCancellable?

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super.init(
      cancellables: cancellables
    )
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
        self?.cancellables.executeOnMainActor { [weak self] in
          self?.navigationController?.presentErrorSnackbar()
          await self?.pop(if: Self.self)
        }
      } receiveValue: { [weak self] resourceWithConfig in
        self?.contentView.update(with: resourceWithConfig)
        MainActor.execute {
          await self?.removeAllChildren(ResourceDetailsLocationSectionView.self)
          await self?.removeAllChildren(ResourceDetailsTagsSectionView.self)
          await self?.removeAllChildren(ResourceDetailsSharedSectionView.self)

          if let resourceID = resourceWithConfig.resource.id {
            await self?.addChild(
              ResourceDetailsLocationSectionView.self,
              in: resourceID
            ) { parent, child in
              parent.insertLocationSection(view: child)
            }

            await self?.addChild(
              ResourceDetailsTagsSectionView.self,
              in: resourceID
            ) { parent, child in
              parent.insertTagsSection(view: child)
            }

            await self?.addChild(
              ResourceDetailsSharedSectionView.self,
              in: resourceID
            ) { parent, child in
              parent.insertShareSection(view: child)
            }
          }  // else skip
        }
      }

    controller
      .resourceMenuPresentationPublisher()
      .sink { [weak self] resourceID in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.presentSheetMenu(
            ResourceMenuViewController.self,
            in: (
              resourceID: resourceID,
              showShare: { [weak self] (resourceID: Resource.ID) in
                self?.controller.presentResourceShare(resourceID)
              },
              showEdit: { [weak self] resourceID in
                self?.controller.presentResourceEdit(resourceID)
              },
              showDeleteAlert: { [weak self] resourceID in self?.controller.presentDeleteResourceAlert(resourceID)
              }
            )
          )
        }
      }
      .store(in: cancellables)

    contentView
      .toggleEncryptedFieldTapPublisher
      .map { [unowned self] field in
        self.controller.toggleDecrypt(field)
          .receive(on: RunLoop.main)
          .handleEvents(
            receiveOutput: { [weak self] value in
              self?.contentView.applyOn(
                field: field,
                buttonMutation: .combined(
                  .when(
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
            }
          )
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
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)

    contentView
      .copyFieldTapPublisher
      .map { [unowned self] field in
        self.controller
          .copyFieldValue(field)
          .receive(on: RunLoop.main)
          .handleEvents(receiveOutput: { [weak self] in
            switch field.name {
            case "uri":
              self?.presentInfoSnackbar(
                .localized("resource.menu.item.field.copied"),
                with: [
                  NSLocalizedString("resource.menu.item.url", bundle: .localization, comment: "")
                ]
              )

            case "password":
              self?.presentInfoSnackbar(
                .localized("resource.menu.item.field.copied"),
                with: [
                  NSLocalizedString("resource.menu.item.password", bundle: .localization, comment: "")
                ]
              )

            case "username":
              self?.presentInfoSnackbar(
                .localized("resource.menu.item.field.copied"),
                with: [
                  NSLocalizedString("resource.menu.item.username", bundle: .localization, comment: "")
                ]
              )

            case "description":
              self?.presentInfoSnackbar(
                .localized("resource.menu.item.field.copied"),
                with: [
                  NSLocalizedString("resource.menu.item.description", bundle: .localization, comment: "")
                ]
              )

            case _:
              self?.presentInfoSnackbar(
                .localized("resource.menu.item.field.copied"),
                with: [field.name]
              )
            }
          })
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
      .store(in: cancellables)

    controller
      .resourceSharePresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] resourceID in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.dismiss(SheetMenuViewController<ResourceMenuViewController>.self)
          await self?.push(
            ResourcePermissionEditListView.self,
            in: resourceID
          )
        }
      }
      .store(in: cancellables)

    controller
      .resourceEditPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] resourceID in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.dismiss(SheetMenuViewController<ResourceMenuViewController>.self)
          await self?.push(
            ResourceEditViewController.self,
            in: (
              .edit(resourceID),
              completion: { [weak self] _ in
                self?.cancellables.executeOnMainActor { [weak self] in
                  self?.presentInfoSnackbar(
                    .localized("resource.menu.action.edited"),
                    presentationMode: .global
                  )
                }
              }
            )
          )
        }
      }
      .store(in: cancellables)

    controller.resourceDeleteAlertPresentationPublisher()
      .sink { [weak self] resourceID in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.dismiss(
            SheetMenuViewController<ResourceMenuViewController>.self
          )
          await self?.present(
            ResourceDeleteAlert.self,
            in: { [weak self] in
              self?.controller.resourceDeletionPublisher(resourceID)
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
                .handleErrors { [weak self] error in
                  switch error {
                  case is Cancelled:
                    return /* NOP */
                  case _:
                    self?.presentErrorSnackbar(error.displayableMessage)
                  }
                }
                .handleEnd { [weak self] ending in
                  self?.resourceDetailsCancellable = nil

                  self?.dismissOverlay()

                  guard case .finished = ending else { return }

                  self?.presentInfoSnackbar(
                    .localized(key: "resource.menu.action.deleted"),
                    with: [
                      NSLocalizedString("resource.menu.item.password", bundle: .localization, comment: "")
                    ],
                    presentationMode: .global
                  )
                  self?.cancellables.executeOnMainActor { [weak self] in
                    await self?.pop(if: Self.self)
                  }
                }
                .sinkDrop()
                .store(in: self?.cancellables)
            }
          )
        }
      }
      .store(in: cancellables)
  }
}
