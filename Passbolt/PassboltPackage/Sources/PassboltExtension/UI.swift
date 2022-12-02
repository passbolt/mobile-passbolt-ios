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

import Accounts
import Display
import UIComponents
import OSFeatures

import class AuthenticationServices.ASPasswordCredentialIdentity

@MainActor
public final class UI {

  private let rootViewController: UIViewController & NavigationTreeRootViewAnchor
  private let features: FeatureFactory

  public init(
    rootViewController: UIViewController & NavigationTreeRootViewAnchor,
    features: FeatureFactory
  ) {
    self.rootViewController = rootViewController
    self.features = features
  }
}

extension UI {

  @MainActor public func prepareCredentialList() {
    Task { @MainActor[weak self] in
        do {
          guard let self = self
          else {
            throw
              InternalInconsistency
              .error("Reference to UI lost.")
          }
          try await self.features
            .instance(of: NavigationTree.self)
            .replaceRoot(
              with: AutofillRootNavigationNodeView.self,
              controller: self.features.instance()
            )
        }
        catch {
          error
            .asTheError()
            .asFatalError(message: "Failed to prepare credentials list.")
        }
      }
  }

  @MainActor public func prepareInterfaceForExtensionConfiguration() {
    Task { @MainActor[weak self] in
        do {
          guard let self = self
          else {
            throw
              InternalInconsistency
              .error("Reference to UI lost.")
          }
          try await self.setRootContent(
            UIComponentFactory(features: self.features)
              .instance(of: ExtensionSetupViewController.self)
          )
        }
        catch {
          error
            .asTheError()
            .asFatalError(message: "Failed to prepare extension configuration.")
        }
      }
  }

  @MainActor private func setRootContent(
    _ viewController: UIViewController
  ) {
    self.rootViewController.children.forEach {
      $0.willMove(toParent: .none)
      $0.view.removeFromSuperview()
      $0.removeFromParent()
    }
    self.rootViewController.addChild(viewController)
    mut(viewController.view) {
      .combined(
        .subview(of: self.rootViewController.view),
        .edges(
          equalTo: self.rootViewController.view,
          usingSafeArea: false
        )
      )
    }
    self.rootViewController
      .didMove(toParent: self.rootViewController)
  }
}
