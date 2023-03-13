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

import CommonModels
import UIKit

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
public final class SheetContentView: PlainView {

  internal var backgroundTapPublisher: AnyPublisher<Void, Never> { backgroundTapSubject.eraseToAnyPublisher() }

  private let backgroundTapSubject: PassthroughSubject<Void, Never> = .init()
  private let container: PlainView = .init()

  public required init() {
    super.init()

    let overlay: PlainView =
      Mutation
      .combined(
        .subview(of: self),
        .backgroundColor(.clear),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, topAnchor),
        .tapGesture { [weak self] _ in
          self?.backgroundTapSubject.send()
        }
      )
      .instantiate()

    mut(container) {
      .combined(
        .backgroundColor(.passboltBackground),
        .shadow(color: .black, opacity: 0),
        .cornerRadius(
          8,
          corners: [.layerMinXMinYCorner, .layerMaxXMinYCorner],
          masksToBounds: true
        ),
        .subview(of: self),
        .leadingAnchor(.equalTo, leadingAnchor),
        .trailingAnchor(.equalTo, trailingAnchor),
        .topAnchor(.equalTo, overlay.bottomAnchor),
        .heightAnchor(.lessThanOrEqualTo, heightAnchor, multiplier: 0.8),
        .bottomAnchor(.equalTo, bottomAnchor)
      )
    }

    mut(self) {
      .backgroundColor(.passboltBackgroundOverlay)
    }
  }

  public func setContent(view: UIView) {
    container.subviews.forEach { $0.removeFromSuperview() }

    mut(view) {
      .combined(
        .subview(of: container),
        .edges(equalTo: container, usingSafeArea: false)
      )
    }
  }
}

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
public struct SheetController<ContentContext> {

  public var contentContext: ContentContext
}

extension SheetController: UIController {

  public typealias Context = ContentContext

  public static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) -> SheetController<ContentContext> {
    Self(
      contentContext: context
    )
  }
}

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
public final class SheetViewController<Content: UIComponent>: PlainViewController, UIComponent {

  public typealias ContentView = SheetContentView
  public typealias Controller = SheetController<Content.Controller.Context>

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

  public let contentView: SheetContentView = .init()
  public var components: UIComponentFactory

  private let controller: Controller

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
    self.modalPresentationStyle = .overFullScreen
    self.modalTransitionStyle = .crossDissolve
  }

  public func setupView() {
    self.cancellables.executeOnMainActor { [weak self] in
      guard let self = self else { return }
      await self.addChild(
        Content.self,
        in: self.controller.contentContext,
        viewSetup: { parentView, childView in
          parentView.setContent(view: childView)
        }
      )

      self.setupSubscriptions()
    }
  }

  private func setupSubscriptions() {
    contentView.backgroundTapPublisher
      .sink { [weak self] in
        self?.cancellables.executeOnMainActor { [weak self] in
          await self?.dismiss(Self.self)
        }
      }
      .store(in: cancellables)
  }
}
