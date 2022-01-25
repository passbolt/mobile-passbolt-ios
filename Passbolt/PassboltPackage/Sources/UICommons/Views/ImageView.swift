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
import Commons

public class ImageView: UIImageView {

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

  public var dynamicBorderColor: DynamicColor? {
    didSet {
      self.layer.borderColor = dynamicBorderColor?(in: traitCollection.userInterfaceStyle).cgColor
    }
  }

  public var useAspectScaleConstraint: Bool = false {
    didSet { updateConstraintsIfNeeded() }
  }

  public init() {
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
  }

  public func setup() {
    // prepared to override instead of overriding init
  }

  private var scaleConstraint: NSLayoutConstraint? {
    didSet {
      oldValue?.isActive = false
      scaleConstraint?.isActive = true
    }
  }

  override public var image: UIImage? {
    get { super.image }
    set {
      super.image = newValue
      updateImageScaleIfNeeded()
    }
  }

  override public var contentMode: UIView.ContentMode {
    get { super.contentMode }
    set {
      super.contentMode = newValue
      updateImageScaleIfNeeded()
    }
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
    self.layer.borderColor = dynamicBorderColor?(in: interfaceStyle).cgColor
  }

  private func updateImageScaleIfNeeded() {
    if useAspectScaleConstraint,
      let image: UIImage = super.image,
      contentMode == .scaleAspectFit
    {
      let width: CGFloat = image.size.width
      let height: CGFloat = image.size.height
      guard width > 0 && height > 0
      else { return scaleConstraint = nil }
      scaleConstraint =
        widthAnchor
        .constraint(
          equalTo: heightAnchor,
          multiplier: width / height
        )
    }
    else {
      scaleConstraint = nil
    }
  }
}
