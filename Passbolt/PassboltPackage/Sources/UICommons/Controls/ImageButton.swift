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

public final class ImageButton: PlainButton {

  public lazy var image: UIImage = imageView.image ?? UIImage() {
    didSet {
      if (!isPressed || pressedImage == nil) && (isEnabled || disabledImage == nil) {
        self.imageView.image = image
      }
      else {
        /* NOP */
      }
    }
  }

  public var pressedImage: UIImage? {
    didSet {
      if let pressedImage: UIImage = pressedImage, isPressed && isEnabled {
        self.imageView.image = pressedImage
      }
      else if isPressed && isEnabled {
        self.imageView.image = image
      }
      else {
        /* NOP */
      }
    }
  }

  public var disabledImage: UIImage? {
    didSet {
      if let disabledImage: UIImage = disabledImage, !isEnabled {
        self.imageView.image = disabledImage
      }
      else if !isEnabled {
        self.imageView.image = image
      }
      else {
        /* NOP */
      }
    }
  }

  public var imageInsets: UIEdgeInsets = .zero {
    didSet {
      self.topImageConstraint?.constant = imageInsets.top
      self.leftImageConstraint?.constant = imageInsets.left
      self.rightImageConstraint?.constant = imageInsets.right
      self.bottomImageConstraint?.constant = imageInsets.bottom
    }
  }
  public var imageContentMode: ContentMode {
    get { imageView.contentMode }
    set { imageView.contentMode = newValue }
  }
  private let imageView: ImageView = .init()
  private var topImageConstraint: NSLayoutConstraint?
  private var leftImageConstraint: NSLayoutConstraint?
  private var rightImageConstraint: NSLayoutConstraint?
  private var bottomImageConstraint: NSLayoutConstraint?

  public required init() {
    super.init()
    setup()
  }

  override internal func pressed() {
    super.pressed()
    guard let pressedImage = pressedImage else { return }
    imageView.image = pressedImage
  }

  override internal func released() {
    super.released()
    imageView.image = image
  }

  override internal func enabled() {
    super.enabled()

    if isPressed {
      imageView.image = pressedImage
    }
    else {
      imageView.image = image
    }
  }

  override internal func disabled() {
    super.disabled()
    guard let disabledImage = disabledImage else { return }
    imageView.image = disabledImage
  }

  private func setup() {
    mut(imageView) {
      .combined(
        .subview(of: self),
        .topAnchor(.equalTo, self.topAnchor, referenceOutput: &self.topImageConstraint),
        .leftAnchor(.equalTo, self.leftAnchor, referenceOutput: &self.leftImageConstraint),
        .rightAnchor(.equalTo, self.rightAnchor, referenceOutput: &self.rightImageConstraint),
        .bottomAnchor(.equalTo, self.bottomAnchor, referenceOutput: &self.bottomImageConstraint)
      )
    }
  }
}
