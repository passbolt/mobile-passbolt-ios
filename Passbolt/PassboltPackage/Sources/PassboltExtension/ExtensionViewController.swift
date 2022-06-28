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

internal final class ExtensionViewController: PlainViewController, UIComponent {

  internal typealias ContentView = UICommons.PlainView
  internal typealias Controller = ExtensionController

  static func instance(
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

  internal func setupView() {
    controller.destinationPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] destination in
        showFeedbackAlertIfNeeded(presentationAnchor: self) { [weak self] in
          self?.children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
          }

          self?.cancellables.executeOnMainActor { [weak self] in
            guard let self = self else { return }
            do {
              switch destination {
              case let .authorization(account):
                try await self.replaceContent(
                  with: self.components
                    .instance(
                      of: AuthorizationNavigationViewController.self,
                      in: (account: account, mode: .signIn)
                    )
                )

              case let .accountSelection(.some(lastUsedAccount)):
                try await self.replaceContent(
                  with: self.components
                    .instance(
                      of: AuthorizationNavigationViewController.self,
                      in: (account: lastUsedAccount, mode: .switchAccount)
                    )
                )

              case .accountSelection(.none):
                try await self.replaceContent(
                  with: self.components
                    .instance(
                      of: AuthorizationNavigationViewController.self,
                      in: (account: nil, mode: .signIn)
                    )
                )

              case .home:
                try await self.replaceContent(
                  with: self.components
                    .instance(
                      of: ResourcesNavigationViewController.self
                    )
                )

              case .mfaRequired:
                try await self.replaceContent(
                  with: self.components
                    .instance(
                      of: PlainNavigationViewController<MFARequiredViewController>.self
                    )
                )
              }
            }
            catch {
              error
                .asTheError()
                .asFatalError()
            }
          }
        }
      }
      .store(in: cancellables)
  }
}

extension ExtensionViewController {

  internal func replaceContent(with content: UIViewController) {
    addChild(content)
    view.addSubview(content.view)
    content.didMove(toParent: self)
  }
}
