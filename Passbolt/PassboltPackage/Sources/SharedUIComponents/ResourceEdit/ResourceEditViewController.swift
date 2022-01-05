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

  public typealias View = ResourceEditView
  public typealias Controller = ResourceEditController

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  public private(set) lazy var contentView: View = .init(createsNewResource: controller.createsNewResource)
  public let components: UIComponentFactory
  private let controller: Controller

  private var fieldCancellables: Cancellables = .init()
  private let showErrorSubject: PassthroughSubject<Void, Never> = .init()

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  public func setupView() {
    mut(navigationItem) {
      .when(
        controller.createsNewResource,
        then: .combined(
          .title(localized: "resource.edit.create.title", inBundle: .sharedUIComponents),
          .leftBarButtonItem(
            Mutation<UIBarButtonItem>
              .combined(
                .backStyle(),
                .action { [weak self] in
                  self?.controller.cleanup()
                  self?.pop(if: Self.self)
                }
              )
              .instantiate()
          )
        ),
        else: .combined(
          .title(localized: "resource.edit.title", inBundle: .sharedUIComponents),
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

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller
      .resourcePropertiesPublisher()
      .receive(on: RunLoop.main)
      .handleErrors(
        (
          [.canceled],
          handler: { _ in true }
        ),
        defaultHandler: { [weak self] _ in
          self?.presentErrorSnackbar()
          self?.pop(if: Self.self)
        }
      )
      .sink(
        receiveCompletion: { _ in /* NOP */ },
        receiveValue: { [weak self] properties in
          self?.contentView.update(with: properties)
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
                    key: .loadingLong,
                    bundle: .commons
                  ),
                  delay: 15
                )
              )
            )
          }
          .handleErrors(
            (
              [.canceled],
              handler: { _ in true /* NOP */ }
            ),
            (
              [.validation],
              handler: { [weak self] error in
                self?.showErrorSubject.send()

                guard
                  let displayable = error.displayableString,
                  let displayableArguments = error.displayableStringArguments
                else { return false }

                self?.presentErrorSnackbar(
                  displayable,
                  with: displayableArguments
                )
                return true
              }
            ),
            defaultHandler: { [weak self] _ in
              self?.presentErrorSnackbar()
            }
          )
          .handleEnd { [weak self] ending in
            self?.dismissOverlay()

            guard case .finished = ending
            else { return }

            self?.pop(if: Self.self)
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
              : "resource.form.description.unencrypted",
            bundle: .commons
          )
        )
      })
      .store(in: cancellables)

    self.controller
      .exitConfirmationPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] presented in
        if presented {
          self?.present(
            ResourceEditExitConfirmationAlert.self,
            in: { [weak self] in
              self?.controller.cleanup()
              self?.pop(if: Self.self)
            }
          )
        }
        else {
          self?.dismiss(ResourceEditExitConfirmationAlert.self)
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
        _ = resourceProperties.map { resourceProperty in
          guard let self = self
          else { return }
          let fieldValuePublisher = self.controller.fieldValuePublisher(resourceProperty.field)

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
                for: resourceProperty.field
              )
            })
            .store(in: self.fieldCancellables)

          self.contentView
            .fieldValuePublisher(for: resourceProperty.field)
            .removeDuplicates()
            .map { [unowned self] value -> AnyPublisher<Void, TheError> in
              self.controller.setValue(value, resourceProperty.field)
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
