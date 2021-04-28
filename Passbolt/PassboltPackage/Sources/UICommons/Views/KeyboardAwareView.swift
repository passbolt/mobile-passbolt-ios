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

import Commons
import UIKit

open class KeyboardAwareView: View {
  
  open class var backgroundTapEditingEndHandlerEnabled: Bool { true }
  
  public private(set) lazy var keyboardSafeAreaLayoutGuide: UILayoutGuide = {
    let guide: UILayoutGuide = .init()
    addLayoutGuide(guide)
    keyboardSafeAreaLayoutGuideTopAnchor = guide.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
    keyboardSafeAreaLayoutGuideTopAnchor.isActive = true
    keyboardSafeAreaLayoutGuideLeadingAnchor = guide.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor)
    keyboardSafeAreaLayoutGuideLeadingAnchor.isActive = true
    keyboardSafeAreaLayoutGuideTrailingAnchor = guide.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor)
    keyboardSafeAreaLayoutGuideTrailingAnchor.isActive = true
    keyboardSafeAreaLayoutGuideBottomAnchor = guide.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
    keyboardSafeAreaLayoutGuideBottomAnchor.isActive = true
    return guide
  }()
  
  private lazy var keyboardSafeAreaLayoutGuideTopAnchor: NSLayoutConstraint
    = .init()
  private lazy var keyboardSafeAreaLayoutGuideLeadingAnchor: NSLayoutConstraint
    = .init()
  private lazy var keyboardSafeAreaLayoutGuideTrailingAnchor: NSLayoutConstraint
    = .init()
  private lazy var keyboardSafeAreaLayoutGuideBottomAnchor: NSLayoutConstraint
    = .init()
  private lazy var backgroundTapGestureDelegate: BackgroundTapGestureDelegate = {
    let backgroundTapGesture: UITapGestureRecognizer
    = .init(
      target: self,
      action: #selector(backgroundTapEditingEndHandler)
    )
    let backgroundTapGestureDelegate: BackgroundTapGestureDelegate
    = .init(backgroundTapGesture: backgroundTapGesture)
    backgroundTapGesture.delegate = backgroundTapGestureDelegate
    self.addGestureRecognizer(backgroundTapGesture)
    return backgroundTapGestureDelegate
  }()
  
  public required init() {
    super.init()
    setupKeyboardHandlers()
    guard Self.backgroundTapEditingEndHandlerEnabled else { return }
    setupBackgroundTapEditingEndHandler()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  private func setupBackgroundTapEditingEndHandler() {
    _ = backgroundTapGestureDelegate // load variable
  }
  
  private func setupKeyboardHandlers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardShow(notification:)),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardHide(notification:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }
  
  // swiftlint:disable legacy_objc_type
  @objc private func keyboardShow(notification: NSNotification) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let notificationInfo = notification.userInfo else { return }
    let keyboardInitialFrame: CGRect = notificationInfo[UIResponder.keyboardFrameBeginUserInfoKey]
      .flatMap { ($0 as? NSValue)?.cgRectValue }
      ?? .zero
    let keyboardFinalFrame: CGRect = notificationInfo[UIResponder.keyboardFrameEndUserInfoKey]
      .flatMap { ($0 as? NSValue)?.cgRectValue }
      ?? .zero
    guard keyboardFinalFrame != keyboardInitialFrame else { return }
    let animationDuration: TimeInterval
      = notificationInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
      ?? 0.25
    let animationOptions: UIView.AnimationOptions
      = .init(
      rawValue: notificationInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
      ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
    )
    let overlappingKeyboardHeight: CGFloat
    if let window: UIWindow = window {
      overlappingKeyboardHeight
        = max(bounds.height - window.convert(keyboardFinalFrame, to: self).minY - safeAreaInsets.bottom, 0)
    } else { // we might skip computations on no window - to verify
      overlappingKeyboardHeight = max(keyboardFinalFrame.height - safeAreaInsets.bottom, 0)
    }
    keyboardSafeAreaLayoutGuideBottomAnchor.constant = -overlappingKeyboardHeight
    setNeedsLayout()
    UIView.animate(
      withDuration: animationDuration,
      delay: 0,
      options: animationOptions,
      animations: {
        self.layoutIfNeeded()
      }
    )
  }
  
  @objc private func keyboardHide(notification: NSNotification) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let notificationInfo = notification.userInfo else { return }
    let keyboardInitialFrame: CGRect = notificationInfo[UIResponder.keyboardFrameBeginUserInfoKey]
      .flatMap { ($0 as? NSValue)?.cgRectValue }
      ?? .zero
    let keyboardFinalFrame: CGRect
      = notificationInfo[UIResponder.keyboardFrameEndUserInfoKey]
      .flatMap { ($0 as? NSValue)?.cgRectValue }
      ?? .zero
    guard keyboardFinalFrame != keyboardInitialFrame else { return }
    let animationDuration: TimeInterval
      = notificationInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
      ?? 0.25
    let animationOptions: UIView.AnimationOptions = .init(
      rawValue: notificationInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
    )
    keyboardSafeAreaLayoutGuideBottomAnchor.constant = 0
    setNeedsLayout()
    UIView.animate(
      withDuration: animationDuration,
      delay: 0,
      options: animationOptions,
      animations: {
        self.layoutIfNeeded()
      }
    )
  }
  
  @objc private func backgroundTapEditingEndHandler() {
    dispatchPrecondition(condition: .onQueue(.main))
    endEditing(true)
  }
}

private final class BackgroundTapGestureDelegate: NSObject, UIGestureRecognizerDelegate {
  
  fileprivate weak var backgroundTapGesture: UIGestureRecognizer?
  
  fileprivate init(backgroundTapGesture: UIGestureRecognizer?) {
    self.backgroundTapGesture = backgroundTapGesture
  }
  
  fileprivate func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    guard gestureRecognizer === backgroundTapGesture else { return true }
    return false
  }
  
  fileprivate func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    !(touch.view is UIControl)
  }
  
  fileprivate func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
    false
  }
}
