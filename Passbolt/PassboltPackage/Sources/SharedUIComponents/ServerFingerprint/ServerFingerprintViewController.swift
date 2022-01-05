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

import Foundation
import UICommons
import UIComponents

public final class ServerFingerprintViewController: PlainViewController, UIComponent {

  public typealias View = ServerFingerprintView
  public typealias Controller = ServerFingerprintController

  public private(set) lazy var contentView: View = .init(
    fingerprint: controller.formattedFingerprint().rawValue
  )

  public let components: UIComponentFactory
  private let controller: Controller

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  public init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  public func setupView() {
    setupSubscriptions()
  }

  private func setupSubscriptions() {
    controller.fingerprintMarkedAsCheckedPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] checked in
        self?.contentView.update(checked: checked)
      }
      .store(in: cancellables)

    contentView.checkedTogglePublisher
      .receive(on: RunLoop.main)
      .map { [weak self] in
        self?.controller.toggleFingerprintMarkedAsChecked()
      }
      .sinkDrop()
      .store(in: cancellables)

    self.contentView.acceptTapPublisher
      .receive(on: RunLoop.main)
      .map { [unowned self] _ -> AnyPublisher<Void, TheError> in
        self.controller.saveFingerprintPublisher()
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { [weak self] completion in
          guard case .failure = completion
          else {
            return
          }
          self?.presentErrorSnackbar(
            .localized(
              key: "server.fingerprint.save.failed",
              bundle: .sharedUIComponents
            )
          )
        },
        receiveValue: { [weak self] in
          self?.pop(to: AuthorizationViewController.self)
        }
      )
      .store(in: cancellables)
  }
}
