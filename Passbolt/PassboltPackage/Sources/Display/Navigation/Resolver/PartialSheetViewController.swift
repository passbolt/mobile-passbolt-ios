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

@available(iOS, deprecated: 16, message: "Please switch to presentation detents")
internal final class PartialSheetViewController<Content: UIViewController>: UIViewController {

  private let content: Content

  internal init(
    wrapping content: Content
  ) {
    self.content = content
    super.init(nibName: .none, bundle: .none)
    self.modalPresentationStyle = .overFullScreen
    self.modalTransitionStyle = .crossDissolve
  }

  @available(*, unavailable)
  internal required init?(coder: NSCoder) {
    unreachable(#function)
  }

  override func loadView() {
    let view: UIView = .init()
    view.backgroundColor = .passboltSheetBackground
    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTap)))

    self.content.view.layer.cornerRadius = 8
    self.content.view.layer.maskedCorners = [
      .layerMinXMinYCorner,
      .layerMaxXMinYCorner,
    ]
    self.content.view.layer.masksToBounds = true

    self.addChild(self.content)
    self.content.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(self.content.view)
    NSLayoutConstraint
      .activate([
        self.content.view.leadingAnchor
          .constraint(equalTo: view.leadingAnchor),
        self.content.view.trailingAnchor
          .constraint(equalTo: view.trailingAnchor),
        self.content.view.bottomAnchor
          .constraint(equalTo: view.bottomAnchor),
        self.content.view.topAnchor
          .constraint(greaterThanOrEqualTo: view.topAnchor),
      ])

    self.view = view
    self.content.didMove(toParent: self)
  }

  @objc internal func backgroundTap() {
    self.dismiss(animated: true)
  }

  override internal func dismiss(
    animated: Bool,
    completion: (() -> Void)? = nil
  ) {
    let presentingViewController: UIViewController? = self.presentingViewController
    super.dismiss(
      animated: animated,
      completion: { [weak presentingViewController] in
        presentingViewController?.setNeedsStatusBarAppearanceUpdate()
        completion?()
      }
    )
  }
}
