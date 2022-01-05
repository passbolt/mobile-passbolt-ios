import AegithalosCocoa
import Commons

public final class LoaderOverlayView: View {

  private let activityIndicator: ActivityIndicator = .init(style: .medium)
  private let containerView: View = .init()
  private var timer: Timer? = nil {
    willSet { timer?.invalidate() }
  }
  private let longLoadingLabel: (label: Label, delay: TimeInterval)?

  public init(
    longLoadingMessage: (message: DisplayableString, delay: TimeInterval)? = nil
  ) {
    if let longLoadingMessage: (message: DisplayableString, delay: TimeInterval) = longLoadingMessage {
      let longLabel: Label = .init()
      mut(longLabel) {
        .combined(
          .font(.inter(ofSize: 12, weight: .medium)),
          .textAlignment(.center),
          .custom { (label: Label) in
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
          },
          .lineBreakMode(.byTruncatingTail),
          .numberOfLines(1),
          .textColor(dynamic: .primaryButtonText),
          .text(displayable: longLoadingMessage.message)
        )
      }
      self.longLoadingLabel = (label: longLabel, delay: longLoadingMessage.delay)
    }
    else {
      self.longLoadingLabel = nil
    }
    super.init()
    dynamicBackgroundColor = .overlayBackground
    mut(containerView) {
      .combined(
        .backgroundColor(dynamic: .backgroundAlert),
        .cornerRadius(8, masksToBounds: true),
        .subview(of: self),
        .widthAnchor(.equalTo, constant: 96),
        .heightAnchor(.equalTo, constant: 96),
        .centerYAnchor(.equalTo, centerYAnchor, constant: 8),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
    }

    Mutation<Label>
      .combined(
        .font(.inter(ofSize: 12, weight: .medium)),
        .textAlignment(.center),
        .custom { (label: Label) in
          label.adjustsFontSizeToFitWidth = true
          label.minimumScaleFactor = 0.5
        },
        .lineBreakMode(.byTruncatingTail),
        .numberOfLines(1),
        .textColor(dynamic: .primaryText),
        .text(localized: .loading, inBundle: .commons),
        .subview(of: containerView),
        .leadingAnchor(.equalTo, containerView.leadingAnchor, constant: 8),
        .trailingAnchor(.equalTo, containerView.trailingAnchor, constant: -8),
        .bottomAnchor(.equalTo, containerView.bottomAnchor, constant: -16)
      )
      .instantiate()

    mut(activityIndicator) {
      .combined(
        .color(dynamic: .icon),
        .subview(of: containerView),
        .centerYAnchor(.equalTo, centerYAnchor),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
    }
  }

  @available(*, unavailable, message: "use init(fingerprint:")
  public required init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  deinit {
    timer?.invalidate()
  }

  override public func willMove(
    toWindow newWindow: UIWindow?
  ) {
    super.willMove(toWindow: newWindow)
    if newWindow != nil {
      if let longLoadingLabel: (label: Label, delay: TimeInterval) = longLoadingLabel {
        timer = .scheduledTimer(withTimeInterval: longLoadingLabel.delay, repeats: false) { [weak self] _ in
          DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            mut(longLoadingLabel.label) {
              .combined(
                .subview(of: self),
                .leadingAnchor(.equalTo, self.leadingAnchor, constant: 16),
                .trailingAnchor(.equalTo, self.trailingAnchor, constant: -16),
                .topAnchor(.equalTo, self.containerView.bottomAnchor, constant: 16)
              )
            }
            self.timer = nil
          }
        }
      }
      else {
        /* NOP */
      }
    }
    else {
      timer = nil
      if let longLoadingLabel: (label: Label, delay: TimeInterval) = longLoadingLabel {
        longLoadingLabel.label.removeFromSuperview()
      }
      else {
        /* NOP */
      }
    }
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }
    superview?.bringSubviewToFront(self)
  }
}
