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

public class Button: UIControl {
  
  public lazy var dynamicBackgroundColor: DynamicColor
  = .default(self.backgroundColor) {
    didSet {
      self.backgroundColor = dynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicPressedBackgroundColor: DynamicColor
  = .default(self.pressedBackgroundColor) {
    didSet {
      self.pressedBackgroundColor = dynamicPressedBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicDisabledBackgroundColor: DynamicColor
  = .default(self.disabledBackgroundColor) {
    didSet {
      self.disabledBackgroundColor = dynamicDisabledBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var dynamicTintColor: DynamicColor
  = .default(self.tintColor) {
    didSet {
      self.tintColor = dynamicTintColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public var pressedBackgroundColor: UIColor? {
    get { pressLayer.backgroundColor.map(UIColor.init(cgColor:)) }
    set { pressLayer.backgroundColor = newValue?.cgColor }
  }
  public var disabledBackgroundColor: UIColor? {
    get { disableLayer.backgroundColor.map(UIColor.init(cgColor:)) }
    set { disableLayer.backgroundColor = newValue?.cgColor }
  }
  public var tapPublisher: AnyPublisher<Void, Never> {
    tapSubject.eraseToAnyPublisher()
  }
  private let tapSubject = PassthroughSubject<Void, Never>()
  private let pressLayer: CALayer = .init()
  private let disableLayer: CALayer = .init()
  
  public private(set) var isPressed: Bool = false {
    didSet {
      guard isPressed != oldValue else { return }
      switch isPressed {
      case true:
        CALayer.performWithoutAnimation {
          pressed()
        }
        
      case false:
        CALayer.performWithoutAnimation {
          released()
        }
      }
    }
  }
  
  override public var isEnabled: Bool {
    didSet {
      guard isEnabled != oldValue else { return }
      switch isEnabled {
      case true:
        enabled()
        
      case false:
        disabled()
      }
    }
  }
  
  public required init() {
    super.init(frame: .zero)
    setup()
  }
  
  @available(*, unavailable)
  public required init?(coder aDecoder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }
  
  internal func pressed() {
    pressLayer.opacity = 1
  }
  
  internal func released() {
    pressLayer.opacity = 0
  }
  
  internal func enabled() {
    disableLayer.opacity = 0
  }
  
  internal func disabled() {
    disableLayer.opacity = 1
  }
  
  private func setup() {
    clipsToBounds = true
    layer.masksToBounds = true
    insetsLayoutMarginsFromSafeArea = false
    setupPressEffect()
    setupDisableEffect()
    setupActions()
  }
  
  private func setupPressEffect() {
    pressLayer.opacity = 0.0
    pressLayer.frame = bounds
    layer.addSublayer(pressLayer)
  }
  
  private func setupDisableEffect() {
    disableLayer.opacity = 0.0
    disableLayer.frame = bounds
    layer.addSublayer(disableLayer)
  }
  
  private func setupActions() {
    addTarget(self, action: #selector(touchDown), for: .touchDown)
    addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
    addTarget(self, action: #selector(touchDragEnter), for: .touchDragEnter)
    addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)
    addTarget(self, action: #selector(touchDragExit), for: .touchDragExit)
    addTarget(self, action: #selector(touchCancel), for: .touchCancel)
  }
  
  @objc private func touchDown() {
    isPressed = true
  }
  
  @objc private func touchUpInside() {
    isPressed = false
    tapSubject.send()
  }
  
  @objc private func touchDragEnter() {
    isPressed = true
  }
  
  @objc private func touchUpOutside() {
    isPressed = false
  }
  
  @objc private func touchDragExit() {
    isPressed = false
  }
  
  @objc private func touchCancel() {
    isPressed = false
  }
  
  override public func layoutSubviews() {
    super.layoutSubviews()
    pressLayer.frame = bounds
    disableLayer.frame = bounds
  }
  
  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }
  
  internal func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.backgroundColor = dynamicBackgroundColor(in: interfaceStyle)
    self.pressedBackgroundColor = dynamicPressedBackgroundColor(in: interfaceStyle)
    self.disabledBackgroundColor = dynamicDisabledBackgroundColor(in: interfaceStyle)
    self.tintColor = dynamicTintColor(in: interfaceStyle)
  }
}
