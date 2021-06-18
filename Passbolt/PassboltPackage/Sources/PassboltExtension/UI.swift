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

import class AuthenticationServices.ASPasswordCredentialIdentity
import UIComponents

public final class UI {
  
  private let rootViewController: UIViewController
  private let features: FeatureFactory
  private let components: UIComponentFactory
  
  public init(
    rootViewController: UIViewController,
    features: FeatureFactory
  ) {
    self.rootViewController = rootViewController
    self.features = features
    self.components = UIComponentFactory(features: features)
  }
}

extension UI {
  
  public func prepareCredentialList() {
    #warning("TODO: [PAS-???] to complete")
    let vc: UIViewController = .init()
    vc.view.backgroundColor = .green
    setRootContent(vc)
  }
  
  public func prepareInterfaceForExtensionConfiguration() {
    setRootContent(components.instance(of: ExtensionSetupViewController.self))
  }
  
  private func setRootContent(_ viewController: UIViewController) {
    rootViewController.children.forEach {
      $0.willMove(toParent: nil)
      $0.view.removeFromSuperview()
      $0.removeFromParent()
    }
    rootViewController.addChild(viewController)
    mut(viewController.view) {
      .combined(
        .subview(of: rootViewController.view),
        .edges(equalTo: rootViewController.view, usingSafeArea: false)
      )
    }
    rootViewController.didMove(toParent: rootViewController)
  }
}
