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

import class AuthenticationServices.ASCredentialProviderViewController
import class AuthenticationServices.ASCredentialServiceIdentifier
import Commons
import Foundation.NSCoder
import UIKit

@objc(RootViewController)
@MainActor internal final class RootViewController: ASCredentialProviderViewController {

  // Not using lazy var - super.init() may trigger viewDidLoad() before
  // the lazy var backing storage is finalized, causing double initialization.
  @MainActor private var applicationExtension: ApplicationExtension?

  @MainActor internal init() {
    super.init(nibName: nil, bundle: nil)
    let appExtension: ApplicationExtension = .init(rootViewController: self)
    self.applicationExtension = appExtension
    appExtension.initialize()
    let rootHostingController: UIViewController = appExtension.makeRootHostingController()
    rootHostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    rootHostingController.view.frame = view.bounds
    addChild(rootHostingController)
    view.addSubview(rootHostingController.view)
    rootHostingController.didMove(toParent: self)
  }

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable(#function)
  }

  @MainActor override internal func prepareCredentialList(
    for serviceIdentifiers: Array<ASCredentialServiceIdentifier>
  ) {
    guard let applicationExtension: ApplicationExtension = self.applicationExtension
    else { return }
    applicationExtension
      .requestSuggestions(for: serviceIdentifiers)
    applicationExtension
      .prepareCredentialList()
  }

  @MainActor override internal func prepareInterfaceForExtensionConfiguration() {
    guard let applicationExtension: ApplicationExtension = self.applicationExtension
    else { return }
    applicationExtension
      .prepareInterfaceForExtensionConfiguration()
  }
}
