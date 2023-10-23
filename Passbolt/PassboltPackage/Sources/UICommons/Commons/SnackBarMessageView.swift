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
import UIKit

/// Setup messages display using given view as
/// an anchor for presenting messages. This will
/// subscrbe to `SnackBarMessageEvent` automatically.
/// It is intended to be used only once for the application
/// on its root view (or window).
@MainActor public func setupSnackBarMessages(
	within presentingView: UIView
) {
	snackBarsTask?.cancel()
	presentingView.isUserInteractionEnabled = true
	snackBarsTask = Task<Void, Error>.detached {
		try await SnackBarMessageEvent.subscribe(bufferSize: 8) { @MainActor (event: SnackBarMessageEvent.Payload) -> Void in
			switch event {
			case .show(let message):
				SnackBarMessageView()
					.present(
						message,
						within: presentingView
					)
			case .clear:
				for view in presentingView.subviews {
					(view as? SnackBarMessageView)?.dismiss()
				}
			}
		}
	}
}

private var snackBarsTask: Task<Void, Error>?

private final class SnackBarMessageView: UIView {

	private let label: Label

	fileprivate required init() {
		self.label = .init()
		super.init(frame: .zero)
		self.setup()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	fileprivate func setup() {
		self.translatesAutoresizingMaskIntoConstraints = false
		self.layer.cornerRadius = 4
		self.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
		self.layer.masksToBounds = true
		self.isUserInteractionEnabled = true

		let tapGesture: UITapGestureRecognizer = .init(
			target: self,
			action: #selector(self.dismiss)
		)
		tapGesture.numberOfTapsRequired = 1
		tapGesture.numberOfTouchesRequired = 1
		self.addGestureRecognizer(tapGesture)

		self.label.font = .inter(
			ofSize: 14,
			weight: .regular
		)
		self.label.textColor = .passboltPrimaryAlertText
		self.label.textAlignment = .left
		self.label.numberOfLines = 0
		self.label.lineBreakMode = .byWordWrapping
		self.label.translatesAutoresizingMaskIntoConstraints = false
		self.label.accessibilityIdentifier = "snackbar.message"
		self.label.isUserInteractionEnabled = false
		self.addSubview(self.label)
		NSLayoutConstraint.activate([
			self.label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
			self.label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
			self.label.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
			self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
		])
	}

	private func prepare(
		for message: SnackBarMessage
	) {
		switch message {
		case .info(let message):
			self.label.text = message.string()
			self.backgroundColor = .passboltBackgroundAlert

		case .error(let message):
			self.label.text = message.string()
			self.backgroundColor = .passboltSecondaryRed
		}
	}

	fileprivate func present(
		_ message: SnackBarMessage,
		within presentingView: UIView
	) {
		self.prepare(for: message)

		self.alpha = 0
		presentingView.addSubview(self)
		NSLayoutConstraint.activate([
			presentingView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: -24),
			presentingView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 24),
			presentingView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 24),
		])

		self.layoutIfNeeded()
		presentingView.bringSubviewToFront(self)

		UIView.animate(
			withDuration: 0.3,
			delay: 0,
			options: [.beginFromCurrentState, .allowUserInteraction],
			animations: { [weak self] in
				self?.alpha = 1
			},
			completion: { [weak self] _ in
				UIView.animate(
					withDuration: 0.3,
					delay: 3,
					options: [.beginFromCurrentState],
					animations: { [weak self] in
						self?.alpha = 0
					},
					completion: { [weak self] (completed: Bool) in
						guard completed else { return }
						self?.removeFromSuperview()
					}
				)
			}
		)
	}

	@objc fileprivate func dismiss() {
		UIView.animate(
			withDuration: 0.3,
			delay: 0,
			options: [.beginFromCurrentState],
			animations: { [weak self] in
				self?.alpha = 0
			},
			completion: { [weak self] (completed: Bool) in
				guard completed else { return }
				self?.removeFromSuperview()
			}
		)
	}

	fileprivate override func hitTest(
		_ point: CGPoint,
		with event: UIEvent?
	) -> UIView? {
		if self.isUserInteractionEnabled, self.bounds.contains(point) {
			return self
		}
		else {
			return .none
		}
	}
}
