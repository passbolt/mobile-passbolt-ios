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

public final class ResourceEditViewController: PlainViewController, UIComponent {

  public typealias ContentView = ResourceEditView
  public typealias Controller = ResourceEditController

  public static func instance(
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

  public init(
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

  public private(set) lazy var contentView: ContentView = .init(createsNewResource: controller.createsNewResource)
  public let components: UIComponentFactory
  private let controller: Controller

  private var fieldCancellables: Cancellables = .init()
  private let showErrorSubject: PassthroughSubject<Void, Never> = .init()

  public func setup() {
    self.title =
      controller.createsNewResource
      ? DisplayableString
        .localized(key: "resource.edit.create.title")
        .string()
      : DisplayableString
        .localized(key: "resource.edit.title")
        .string()

    mut(navigationItem) {
      .when(
        controller.createsNewResource,
        then: .combined(
          .title(.localized(key: "resource.edit.create.title")),
          .leftBarButtonItem(
            Mutation<UIBarButtonItem>
              .combined(
                .backStyle(),
                .action { [weak self] in
                  self?.cancellables.executeOnMainActor { [weak self] in
                    self?.controller.cleanup()
                    await self?.pop(if: Self.self)
                  }
                }
              )
              .instantiate()
          )
        ),
        else: .combined(
          .title(.localized(key: "resource.edit.title")),
          .leftBarButtonItem(
            Mutation<UIBarButtonItem>
              .combined(
                .backStyle(),
                .action { [weak self] in
                  self?.controller.presentExitConfirmation()
                }
              )
              .instantiate()
          )
        )
      )
    }
  }

  public func setupView() {
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .resourcePropertiesPublisher()
      .receive(on: RunLoop.main)
      .handleErrors { [weak self] error in
        switch error {
        case is Cancelled:
          return /* NOP */
        case _:
          self?.cancellables.executeOnMainActor { [weak self] in
            self?.presentErrorSnackbar(error.displayableMessage)
            await self?.pop(if: Self.self)
          }
        }
      }
      .sink(
        receiveCompletion: { _ in /* NOP */ },
        receiveValue: { [weak self] fields in
          self?.contentView.update(with: fields)
          self?.setupFieldSubscriptions()
        }
      )
      .store(in: cancellables)

    controller.passwordEntropyPublisher()
      .receive(on: RunLoop.main)
      .sink(receiveValue: { [weak self] entropy in
        self?.contentView.update(entropy: entropy)
      })
      .store(in: cancellables)

    contentView.createTapPublisher
      .map { [unowned self] _ -> AnyPublisher<Void, Never> in
        self.controller
          .sendForm()
          .receive(on: RunLoop.main)
          .handleStart { [weak self] in
            self?.present(
              overlay: LoaderOverlayView(
                longLoadingMessage: (
                  message: .localized(
                    key: .loadingLong
                  ),
                  delay: 15
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
            self?.cancellables.executeOnMainActor { [weak self] in
              self?.dismissOverlay()

              guard case .finished = ending
              else { return }

              await self?.pop(if: Self.self)
            }
          }
          .mapToVoid()
          .replaceError(with: Void())
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)

    contentView.generateTapPublisher
      .map { [unowned self] in
        self.controller.generatePassword()
      }
      .sinkDrop()
      .store(in: cancellables)

    contentView.lockTapPublisher
      .sink(receiveValue: { [weak self] encrypted in
        self?.presentInfoSnackbar(
          .localized(
            key: encrypted
              ? "resource.form.description.encrypted"
              : "resource.form.description.unencrypted"
          )
        )
      })
      .store(in: cancellables)

    self.controller
      .exitConfirmationPresentationPublisher()
      .sink { [weak self] presented in
        self?.cancellables.executeOnMainActor { [weak self] in
          if presented {
            await self?.present(
              ResourceEditExitConfirmationAlert.self,
              in: { [weak self] in
                self?.cancellables.executeOnMainActor { [weak self] in
                  self?.controller.cleanup()
                  await self?.pop(if: Self.self)
                }
              }
            )
          }
          else {
            await self?.dismiss(ResourceEditExitConfirmationAlert.self)
          }
        }
      }
      .store(in: cancellables)
  }

  private func setupFieldSubscriptions() {
    fieldCancellables = .init()

    controller
      .resourcePropertiesPublisher()
      .first()
      .receive(on: RunLoop.main)
      .handleEvents(receiveOutput: { [weak self] resourceProperties in
        _ = resourceProperties.map { resourceField in
          guard let self = self
          else { return }
          let fieldValuePublisher = self.controller.fieldValuePublisher(resourceField.name)

          fieldValuePublisher
            .first()  // skipping error just to update intial value
            .map { Validated.valid($0.value) }
            .merge(
              with:
                fieldValuePublisher
                .dropFirst()
            )
            .merge(
              with:
                // the subject is used as a trigger for showing error on the form, initially no errors are shown
                self.showErrorSubject
                .map { fieldValuePublisher.first() }
                .switchToLatest()
            )
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] validated in
              self?.contentView.update(
                validated: validated,
                for: resourceField.name
              )
            })
            .store(in: self.fieldCancellables)

          self.contentView
            .fieldValuePublisher(for: resourceField.name)
            .removeDuplicates()
            .map { [unowned self] value -> AnyPublisher<Void, Error> in
              self.controller.setValue(value, resourceField.name)
            }
            .switchToLatest()
            .sinkDrop()
            .store(in: self.fieldCancellables)
        }
      })
      .sinkDrop()
      .store(in: fieldCancellables)
  }
}
