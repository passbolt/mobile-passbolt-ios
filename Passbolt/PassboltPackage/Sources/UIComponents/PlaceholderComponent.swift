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

import AegithalosCocoa

#warning("FIXME: let it be only in DEBUG before release, allowing for dev builds now")

public final class PlaceholderView: View {
  
  public required init() {
    super.init()
    
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background)
      )
    }
    
    let label: Label = .init()
    mut(label) {
      .combined(
        .titleStyle(),
        .text("🚧 Not completed yet 🚧"),
        .subview(of: self),
        .edges(equalTo: self)
      )
    }
  }
}

public struct PlaceholderController {}

extension PlaceholderController: UIController {
  
  public typealias Context = Void
  
  public static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    Self()
  }
}

public final class PlaceholderViewController: PlainViewController, UIComponent {

  public typealias View = PlaceholderView
  public typealias Controller = PlaceholderController
  
  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }
  
  public var components: UIComponentFactory
  private let controller: Controller
  public private(set) lazy var contentView: View = .init()
  
  public init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }
  
  public func setupView() {}
}
