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

open class StackView: UIStackView {

  public lazy var dynamicBackgroundColor: DynamicColor = .always(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public var dynamicTintColor: DynamicColor? {
    didSet {
      self.tintColor = dynamicTintColor?(in: traitCollection.userInterfaceStyle)
    }
  }

  public required init() {
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  public required init(coder: NSCoder) {
    unreachable(#function)
  }

  open func setup() {
    // prepared to override instead of overriding init
  }

  public func appendSpace(of size: CGFloat, tag: Int? = nil) {
    let space: PlainView = .init()

    if let tag = tag {
      space.tag = tag
    }
    else {
      /* NOP */
    }
    switch axis {
    case .horizontal:
      space.widthAnchor.constraint(equalToConstant: size).isActive = true

    case .vertical:
      space.heightAnchor.constraint(equalToConstant: size).isActive = true
    @unknown default:
      fatalError("Unexpected state")
    }
    addArrangedSubview(space)
  }

  public func appendFiller(
    minSize: CGFloat = 0,
    tag: Int? = .none
  ) {
    let filler: PlainView = .init()
    if let newTag: Int = tag {
      filler.tag = newTag
    }
    else { /* NOP */
    }
    switch axis {
    case .horizontal:
      filler.widthAnchor.constraint(greaterThanOrEqualToConstant: minSize).isActive = true

    case .vertical:
      filler.heightAnchor.constraint(greaterThanOrEqualToConstant: minSize).isActive = true

    @unknown default:
      fatalError("Unexpected state")
    }
    addArrangedSubview(filler)
  }

  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }

  private func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.backgroundColor = dynamicBackgroundColor(in: interfaceStyle)
    self.tintColor = dynamicTintColor?(in: interfaceStyle)
  }
}
