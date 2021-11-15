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

public final class ImageButton: Button {

  public lazy var dynamicImage: DynamicImage = .default(self.imageView.image) {
    didSet {
      if (!isPressed || dynamicPressedImage == nil) && (isEnabled || dynamicDisabledImage == nil) {
        self.imageView.dynamicImage = dynamicImage
      }
      else {
        /* NOP */
      }
    }
  }

  public var dynamicPressedImage: DynamicImage? {
    didSet {
      if let dynamicPressedImage: DynamicImage = dynamicPressedImage, isPressed && isEnabled {
        self.imageView.dynamicImage = dynamicPressedImage
      }
      else if isPressed && isEnabled {
        self.imageView.dynamicImage = dynamicImage
      }
      else {
        /* NOP */
      }
    }
  }

  public var dynamicDisabledImage: DynamicImage? {
    didSet {
      if let dynamicDisabledImage: DynamicImage = dynamicDisabledImage, !isEnabled {
        self.imageView.dynamicImage = dynamicDisabledImage
      }
      else if !isEnabled {
        self.imageView.dynamicImage = dynamicImage
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
    guard let pressedImage = dynamicPressedImage?(in: traitCollection.userInterfaceStyle) else { return }
    imageView.image = pressedImage
  }

  override internal func released() {
    super.released()
    imageView.image = dynamicImage(in: traitCollection.userInterfaceStyle)
  }

  override internal func enabled() {
    super.enabled()

    if isPressed {
      imageView.image = dynamicPressedImage?(in: traitCollection.userInterfaceStyle)
    }
    else {
      imageView.image = dynamicImage(in: traitCollection.userInterfaceStyle)
    }
  }

  override internal func disabled() {
    super.disabled()
    guard let disabledImage = dynamicDisabledImage?(in: traitCollection.userInterfaceStyle) else { return }
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

  override internal func updateColors() {
    super.updateColors()

    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle

    switch (isEnabled, isPressed) {
    case (false, false), (false, true):
      imageView.image = dynamicDisabledImage?(in: interfaceStyle) ?? dynamicImage(in: interfaceStyle)

    case (true, false):
      imageView.image = dynamicImage(in: interfaceStyle)

    case (true, true):
      imageView.image = dynamicPressedImage?(in: interfaceStyle) ?? dynamicImage(in: interfaceStyle)
    }
  }
}
