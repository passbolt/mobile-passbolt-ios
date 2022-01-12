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

import UIKit

extension UIApplication {

  public static func showInfoAlert(
    title: DisplayableString,
    message: DisplayableString,
    buttonTitle: DisplayableString,
    presentationAnchor: UIViewController? = nil,
    completion: @escaping () -> Void
  ) {
    dispatchPrecondition(condition: .onQueue(.main))

    let windows: Array<UIWindow>? = UIApplication
      .shared
      .connectedScenes
      .filter { $0.activationState == .foregroundActive }
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows

    let anchor: UIViewController? =
      presentationAnchor
      ?? windows?
      .first(where: \.isKeyWindow)?
      .rootViewController
      ?? windows?
      .first?
      .rootViewController

    guard let anchor: UIViewController = anchor
    else { return completion() }

    let alert: UIAlertController = .init(
      title: title.string(),
      message: message.string(),
      preferredStyle: .alert
    )
    alert.addAction(
      .init(
        title: buttonTitle.string(),
        style: .default,
        handler: { _ in completion() }
      )
    )

    anchor.present(
      alert,
      animated: true,
      completion: nil
    )
  }
}
