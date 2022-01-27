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

open class ScrolledStackView: UIScrollView {

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

  private let stackView: StackView = .init()

  public required init() {
    super.init(frame: .zero)
    contentSetup()
    setup()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
  }

  open func setup() {
    // prepared to override instead of overriding init
  }

  public var axis: NSLayoutConstraint.Axis {
    get { stackView.axis }
    set {
      precondition(
        stackView.arrangedSubviews.isEmpty,
        "Axis change in non empty \(Self.self) is not supported"
      )
      stackView.axis = newValue
    }
  }

  public var spacing: CGFloat {
    get { stackView.spacing }
    set { stackView.spacing = newValue }
  }

  override public var contentInset: UIEdgeInsets {
    get { stackView.layoutMargins }
    set { stackView.layoutMargins = newValue }
  }

  public var isLayoutMarginsRelativeArrangement: Bool {
    get { stackView.isLayoutMarginsRelativeArrangement }
    set { stackView.isLayoutMarginsRelativeArrangement = newValue }
  }

  public func append(_ view: UIView) {
    stackView.addArrangedSubview(view)
  }

  public func append(views: Array<UIView>) {
    views.forEach(stackView.addArrangedSubview)
  }

  public func insert(_ view: UIView, at index: Int) {
    stackView.insertArrangedSubview(view, at: index)
  }

  public func appendSpace(of size: CGFloat, tag: Int? = nil) {
    stackView.appendSpace(of: size, tag: tag)
  }

  public func appendFiller(minSize: CGFloat = 0) {
    stackView.appendFiller(minSize: minSize)
  }

  public func removeAllArrangedSubviews(withTag: Int? = nil) {
    stackView.arrangedSubviews
      .filter { subview in withTag.map { subview.tag == $0 } ?? true }
      .forEach { $0.removeFromSuperview() }
  }

  private func contentSetup() {
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    insetsLayoutMarginsFromSafeArea = true

    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.distribution = .fill
    stackView.translatesAutoresizingMaskIntoConstraints = false

    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.widthAnchor.constraint(equalTo: widthAnchor),
      {
        let constraint: NSLayoutConstraint = stackView.heightAnchor
          .constraint(equalTo: safeAreaLayoutGuide.heightAnchor)
        constraint.priority = .defaultLow
        return constraint
      }(),
    ])
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

  open override var intrinsicContentSize: CGSize { stackView.intrinsicContentSize }
}
