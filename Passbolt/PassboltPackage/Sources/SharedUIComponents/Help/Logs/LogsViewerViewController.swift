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

public final class LogsViewerViewController: PlainViewController, UIComponent {

  public typealias View = LogsViewerView
  public typealias Controller = LogsViewerController

  public private(set) lazy var contentView: View = .init()

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
    mut(self.navigationItem) {
      .combined(
        .title(.localized(key: "help.logs.viewer.title")),
        .rightBarButtonItem(
          Mutation<UIBarButtonItem>.combined(
            .style(.done),
            .image(named: .open, from: .uiCommons),
            .action { [weak self] in
              self?.controller.presentShareMenu()
            }
          )
          .instantiate()
        ),
        .when(
          navigationController?.viewControllers.count == 1,
          then:
            .leftBarButtonItem(
              Mutation<UIBarButtonItem>.combined(
                .style(.done),
                .image(named: .close, from: .uiCommons),
                .action { [weak self] in
                  self?.dismiss(Self.self)
                }
              )
              .instantiate()
            )
        )

      )
    }

    setupSubscriptions()
  }

  public func activate() {
    controller.refreshLogs()
  }

  private func setupSubscriptions() {
    controller
      .logsPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] logs in
        let logListItems: Array<LogsViewerLogItem>
        if let logs: Array<String> = logs {
          if logs.isEmpty {
            logListItems = [
              LogsViewerLogItem(log: "N/A")
            ]
          }
          else {
            logListItems = logs.map(LogsViewerLogItem.init(log:))
          }
        }
        else {
          logListItems = []
        }
        self?.contentView.update(data: logListItems)
      }
      .store(in: cancellables)

    controller
      .shareMenuPresentationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] logs in
        if let logs: String = logs {
          self?.present(
            UIActivityViewController(
              activityItems: [logs],
              applicationActivities: nil
            ),
            animated: true,
            completion: nil
          )
        }
        else if self?.presentedViewController != nil {
          // assuming that it won't present anything besides share menu
          self?.dismiss(animated: true, completion: nil)
        }
        else { /* NOP */
        }
      }
      .store(in: cancellables)
  }
}
