import AegithalosCocoa
import Commons

public final class LoaderOverlayView: View {

  private let activityIndicator: ActivityIndicator = .init(style: .medium)
  private let label: Label = .init()

  public required init() {
    super.init()
    dynamicBackgroundColor = .overlayBackground
    let containerView: View =
      Mutation
      .combined(
        .backgroundColor(dynamic: .divider),
        .cornerRadius(8, masksToBounds: true),
        .subview(of: self),
        .widthAnchor(.equalTo, constant: 96),
        .heightAnchor(.equalTo, constant: 96),
        .centerYAnchor(.equalTo, centerYAnchor, constant: 8),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
      .instantiate()

    Mutation<Label>
      .combined(
        .font(.inter(ofSize: 12, weight: .medium)),
        .textAlignment(.center),
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

  override public func willMove(
    toWindow newWindow: UIWindow?
  ) {
    super.willMove(toWindow: newWindow)
    if newWindow != nil {
      activityIndicator.startAnimating()
    }
    else {
      activityIndicator.stopAnimating()
    }
  }
}
