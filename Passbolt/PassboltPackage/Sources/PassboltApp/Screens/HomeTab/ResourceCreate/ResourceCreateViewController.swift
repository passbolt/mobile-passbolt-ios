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

internal final class ResourceCreateViewController: PlainViewController, UIComponent {

  internal typealias View = ResourceCreateView
  internal typealias Controller = ResourceCreateController

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

  internal func setupView() {
    mut(navigationItem) {
      .combined(
        .title(localized: "resource.create.title", inBundle: .main),
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
      )
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller.resourceFieldsPublisher()
      .receive(on: RunLoop.main)
      .sink(
        receiveCompletion: { [weak self] completion in
          guard case .failure = completion
          else { return }

          self?.presentErrorSnackbar()
        },
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
        self.controller.createResource()
          .receive(on: RunLoop.main)
          .handleStart { [weak self] in
            self?.present(overlay: LoaderOverlayView())
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
                  let localizationKey = error.localizationKey,
                  let localizationBundle = error.localizationBundle
                else { return false }

                self?.presentErrorSnackbar(
                  localizableKey: .init(stringLiteral: localizationKey),
                  inBundle: localizationBundle
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

            self?.parent?.presentInfoSnackbar(
              localizableKey: "resource.form.new.password.created",
              inBundle: .commons
            )

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
      .sink(receiveValue: { [weak self] in
        self?.presentInfoSnackbar(
          localizableKey: "resource.form.description.encrypted",
          inBundle: .commons,
          presentationAnchor: self?.contentView.lockAnchor
        )
      })
      .store(in: cancellables)

  }

  private func setupFieldSubscriptions() {
    fieldCancellables = .init()

    controller.resourceFieldsPublisher()
      .first()
      .receive(on: RunLoop.main)
      .handleEvents(receiveOutput: { [weak self] resourceFields in
        _ = resourceFields.map { resourceField in
          guard let self = self
          else { return }
          let fieldValuePublisher = self.controller.fieldValuePublisher(resourceField.name().rawValue)

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
                self.showErrorSubject // the subject is used as a trigger for showing error on the form, initially no errors are shown
                .map { fieldValuePublisher.first() }
                .switchToLatest()
            )
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] validated in
              self?.contentView.update(
                validated: validated,
                for: resourceField
              )
            })
            .store(in: self.fieldCancellables)

          self.contentView.fieldValuePublisher(for: resourceField)
            .map { [unowned self] value -> AnyPublisher<Void, TheError> in
              self.controller.setValue(value, resourceField.name().rawValue)
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
