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
import SwiftUI
import UIKit

/// Setup messages display using given view as
/// an anchor for presenting messages. This will
/// subscribe to `SnackBarMessageEvent` automatically.
/// It is intended to be used only once for the application
/// on its root view (or window).
@MainActor public func setupSnackBarMessages(
  within presentingView: UIView
) {
  // Clean up any previous state
  snackBarState?.cancel()
  snackBarContainerView?.removeFromSuperview()
  snackBarHostingController = nil
  snackBarContainerView = nil
  snackBarState = nil

  let state: SnackBarState = .init(presentingView: presentingView)
  snackBarState = state

  let hostingController: UIHostingController<SnackBarContainerView> = .init(
    rootView: SnackBarContainerView()
  )
  hostingController.view.backgroundColor = .clear
  hostingController.view.isOpaque = false
  if #available(iOS 16.4, *) {
    hostingController.safeAreaRegions = .init()
  }
  snackBarHostingController = hostingController

  let passthroughView: TouchPassthroughView = .init()
  passthroughView.translatesAutoresizingMaskIntoConstraints = false

  guard let hostedView: UIView = hostingController.view else {
    assertionFailure("UIHostingController should always have a view!")
    return
  }

  hostedView.translatesAutoresizingMaskIntoConstraints = false
  hostedView.backgroundColor = .clear
  hostedView.isOpaque = false
  passthroughView.addSubview(hostedView)
  NSLayoutConstraint.activate([
    hostedView.leadingAnchor.constraint(equalTo: passthroughView.leadingAnchor),
    hostedView.trailingAnchor.constraint(equalTo: passthroughView.trailingAnchor),
    hostedView.topAnchor.constraint(equalTo: passthroughView.topAnchor),
    hostedView.bottomAnchor.constraint(equalTo: passthroughView.bottomAnchor),
  ])

  presentingView.addSubview(passthroughView)
  NSLayoutConstraint.activate([
    passthroughView.leadingAnchor.constraint(equalTo: presentingView.leadingAnchor),
    passthroughView.trailingAnchor.constraint(equalTo: presentingView.trailingAnchor),
    passthroughView.topAnchor.constraint(equalTo: presentingView.topAnchor),
    passthroughView.bottomAnchor.constraint(equalTo: presentingView.bottomAnchor),
  ])

  snackBarContainerView = passthroughView

  // Start event observation after everything is set up
  state.startObserving()
}

// MARK: - Module-level storage

private var snackBarState: SnackBarState?
private var snackBarHostingController: UIHostingController<SnackBarContainerView>?
private var snackBarContainerView: UIView?

// MARK: - SnackBarState

@MainActor
private final class SnackBarState {

  private(set) var currentMessage: SnackBarMessage?
  private(set) var isVisible: Bool = false
  private(set) var keyboardHeight: CGFloat = 0

  private weak var presentingView: UIView?
  private var eventSubscriptionTask: Task<Void, Error>?
  private var autoDismissTask: Task<Void, Never>?
  private var cleanupTask: Task<Void, Never>?

  fileprivate init(presentingView: UIView) {
    self.presentingView = presentingView
  }

  deinit {
    eventSubscriptionTask?.cancel()
    autoDismissTask?.cancel()
    cleanupTask?.cancel()
  }

  fileprivate func startObserving() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillChangeFrame(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification,
      object: nil
    )

    eventSubscriptionTask = Task<Void, Error>
      .detached { [weak self] in
        let handler: (@MainActor (SnackBarMessageEvent.Payload) -> Void)? = self?.handleSnackBarMessageEvent
        try await SnackBarMessageEvent.subscribe(bufferSize: 8) {
          await handler?($0)
        }
      }
  }

  @MainActor
  private func handleSnackBarMessageEvent(_ event: SnackBarMessageEvent.Payload) {
    switch event {
    case .show(let message):
      self.show(message)
    case .clear:
      self.dismiss()
    }
  }

  fileprivate func cancel() {
    eventSubscriptionTask?.cancel()
    autoDismissTask?.cancel()
    cleanupTask?.cancel()
    NotificationCenter.default.removeObserver(self)
  }

  private func show(_ message: SnackBarMessage) {
    autoDismissTask?.cancel()
    cleanupTask?.cancel()

    // Bring container to front so it's not covered by other views
    if let containerView: UIView = snackBarContainerView {
      containerView.superview?.bringSubviewToFront(containerView)
    }

    currentMessage = message
    isVisible = true
    updateHostingControllerAnimated()

    autoDismissTask = Task<Void, Never> { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      self?.dismiss()
    }
  }

  private func dismiss() {
    autoDismissTask?.cancel()
    cleanupTask?.cancel()
    isVisible = false
    updateHostingControllerAnimated()

    cleanupTask = Task<Void, Never> { [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      self?.currentMessage = nil
    }
  }

  private func updateHostingControllerAnimated() {
    guard let hostingController: UIHostingController<SnackBarContainerView> = snackBarHostingController
    else { return }
    withAnimation(.easeInOut(duration: 0.3)) {
      hostingController.rootView = makeContainerView()
    }
  }

  private func updateHostingController(animationDuration: TimeInterval) {
    guard let hostingController: UIHostingController<SnackBarContainerView> = snackBarHostingController
    else { return }
    withAnimation(.easeInOut(duration: animationDuration)) {
      hostingController.rootView = makeContainerView()
    }
  }

  private func makeContainerView() -> SnackBarContainerView {
    SnackBarContainerView(
      currentMessage: currentMessage,
      isVisible: isVisible,
      keyboardHeight: keyboardHeight,
      onDismiss: { [weak self] in self?.dismiss() }
    )
  }

  @objc private func keyboardWillChangeFrame(
    _ notification: Notification
  ) {
    guard
      let userInfo: Dictionary<AnyHashable, Any> = notification.userInfo,
      let keyboardFrame: CGRect = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    else { return }

    let screenHeight: CGFloat = UIScreen.main.bounds.height
    let keyboardTop: CGFloat = screenHeight - keyboardFrame.origin.y
    let safeAreaBottom: CGFloat = presentingView?.safeAreaInsets.bottom ?? 0
    let duration: TimeInterval =
      userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25

    let newHeight: CGFloat
    if keyboardTop > safeAreaBottom {
      newHeight = keyboardTop - safeAreaBottom
    }
    else {
      newHeight = 0
    }

    keyboardHeight = newHeight
    updateHostingController(animationDuration: duration)
  }
}

// MARK: - SnackBarContentView

private struct SnackBarContentView: View {

  private let message: SnackBarMessage
  private let onDismiss: () -> Void

  fileprivate init(message: SnackBarMessage, onDismiss: @escaping () -> Void) {
    self.message = message
    self.onDismiss = onDismiss
  }

  fileprivate var body: some View {
    Text(text)
      .font(.inter(ofSize: 14, weight: .regular))
      .foregroundColor(.passboltPrimaryAlertText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .onTapGesture {
        onDismiss()
      }
  }

  private var backgroundColor: Color {
    switch message {
    case .info:
      return .passboltBackgroundAlert
    case .error:
      return .passboltSecondaryRed
    }
  }

  private var text: String {
    switch message {
    case .info(let displayable):
      return displayable.string().capitalizedFirstLetter
    case .error(let displayable):
      return displayable.string().capitalizedFirstLetter
    }
  }
}

// MARK: - SnackBarContainerView

private struct SnackBarContainerView: View {

  private let currentMessage: SnackBarMessage?
  private let isVisible: Bool
  private let keyboardHeight: CGFloat
  private let onDismiss: () -> Void

  fileprivate init(
    currentMessage: SnackBarMessage? = .none,
    isVisible: Bool = false,
    keyboardHeight: CGFloat = 0,
    onDismiss: @escaping () -> Void = {}
  ) {
    self.currentMessage = currentMessage
    self.isVisible = isVisible
    self.keyboardHeight = keyboardHeight
    self.onDismiss = onDismiss
  }

  fileprivate var body: some View {
    ZStack(alignment: .bottom) {
      Color
        .clear
        .allowsHitTesting(false)

      if isVisible, let message: SnackBarMessage = currentMessage {
        SnackBarContentView(
          message: message,
          onDismiss: onDismiss
        )
        .padding(.horizontal, 24)
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 40 : 32)
        .transition(.opacity)
      }
    }
    .ignoresSafeArea(.keyboard)
  }
}

// MARK: - TouchPassthroughView

private final class TouchPassthroughView: UIView {

  override fileprivate func hitTest(
    _ point: CGPoint,
    with event: UIEvent?
  ) -> UIView? {
    let result: UIView? = super.hitTest(point, with: event)
    if result === self { return nil }
    if result === self.subviews.first { return nil }
    return result
  }
}
